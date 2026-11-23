-- Font files contain fixed-size glyph records shared by the canvas and wall export.
local M={limit=256,fonts={
    "Slab","Poster","Script","Pixel",
    "Brush","Daub","Drippy","Flow",
    "Arcade","Terminal","Circuit","Speedway",
    "Stack","Varsity","Gothic","Western",
    "Neon","Shade","Horror","Deco",
}}
local banks={}
local mappings
local writingFaces={}
local cached=setmetatable({},{__mode="k"})
local recordSize=36
local replacement={width=8,rows={32768+256,32512,16896,17664,19200,18176,17152,16896,16896,16896,16896,16896,32512,0,0,0}}

local function glyph(face,cp)
    local bank=banks[face]
    if not bank then
        bank={data=reskate.package.read("art/lettering/"..face..".glfont") or "",lookup={}}
        banks[face]=bank
    end
    local found=bank.lookup[cp]
    if found~=nil then return found end
    local lo,hi=0,math.floor(#bank.data/recordSize)-1
    while lo<=hi do
        local mid=math.floor((lo+hi)/2)
        local at=1+mid*recordSize
        local a,b,c,width=bank.data:byte(at,at+3)
        local id=(a*256+b)*256+c
        if id<cp then lo=mid+1
        elseif id>cp then hi=mid-1
        else
            local rows=table.create(16)
            for i=1,16 do
                a,b=bank.data:byte(at+2+i*2,at+3+i*2)
                rows[i]=a*256+b
            end
            found={width=width,rows=rows}
            break
        end
    end
    -- Layouts retain the glyphs they use. Bound the shared lookup for long sessions.
    if (bank.count or 0)>=1024 then table.clear(bank.lookup) bank.count=0 end
    bank.count=(bank.count or 0)+1
    bank.lookup[cp]=found or false
    return found
end

function M.limitText(s)
    if not utf8.len(s) then return nil end
    local stop=utf8.offset(s,M.limit+1)
    return if stop then s:sub(1,stop-1) else s
end

local function mark(cp)
    return (cp>=0x300 and cp<=0x36f) or (cp>=0x1ab0 and cp<=0x1aff) or (cp>=0x1dc0 and cp<=0x1dff)
        or (cp>=0x591 and cp<=0x5bd) or cp==0x5bf or (cp>=0x5c1 and cp<=0x5c2)
        or (cp>=0x64b and cp<=0x65f) or cp==0x670
end
local function direction(cp)
    if (cp>=0x660 and cp<=0x669) or (cp>=0x6f0 and cp<=0x6f9) then return 1 end
    if (cp>=0x590 and cp<=0x8ff) or (cp>=0xfb1d and cp<=0xfefc) then return -1 end
    if cp>=0x30 and cp<=0x39 or cp>=0x41 and cp<=0x5a or cp>=0x61 and cp<=0x7a or cp>=0xc0 then return 1 end
    return 0
end
local function ordered(line)
    local runs,base={},nil
    for _,g in line do
        local dir=direction(g.cp)
        if dir~=0 and not base then base=dir end
        local run=runs[#runs]
        if not run or (dir~=0 and dir~=run.dir) then
            run={dir=dir,items={}} table.insert(runs,run)
        end
        table.insert(run.items,g)
    end
    local out={}
    for i=1,#runs do
        local run=runs[if base==-1 then #runs+1-i else i]
        for j=1,#run.items do table.insert(out,run.items[if run.dir==-1 then #run.items+1-j else j]) end
    end
    return out
end

-- Pixel positions share the typeface's baseline. The advance moves the pen;
-- ink may start before that pen or overlap the next letter in a script face.
local function writingLayout(l,groups)
    if not l.natural or not l.font or l.font=="Pixel" then return end
    local face=writingFaces[l.font]
    if face==nil then
        face=reskate.package.read_json("art/lettering/"..l.font..".metrics.json")
        if face then face.ink=reskate.package.read("art/lettering/"..l.font..".ink") end
        writingFaces[l.font]=if face and face.ink then face else false
        face=writingFaces[l.font]
    end
    if not face then return end
    for _,g in groups do
        if #g.marks>0 then return end
        g.metric=face.glyphs[utf8.char(g.cp)]
        if g.cp~=10 and not g.metric then return end
    end
    local lineHeight=face.line
    local gap=l.spacing*3
    local result={smooth=true,width=1,lines={},characters={},lineHeight=lineHeight,ink=face.ink}
    local row,pen
    local function nextLine()
        row={columns={},left=0,width=0}
        table.insert(result.lines,row)
        pen=0
    end
    nextLine()
    for i,g in groups do
        if g.cp==10 then nextLine() continue end
        local m=g.metric
        local needed=m[1]
        if i>1 and groups[i-1].cp==32 and g.cp~=32 then
            for j=i+1,#groups do
                local after=groups[j]
                if after.cp==32 or after.cp==10 then break end
                needed+=gap+after.metric[1]
            end
        end
        if pen>0 and pen+math.min(needed,640)>640 and g.cp~=32 then nextLine() end
        g.row=#result.lines
        g.x,g.y=pen+m[2],(g.row-1)*lineHeight+face.base+m[3]
        g.pen=pen
        row.left=math.min(row.left,g.x)
        row.width=math.max(row.width,pen+m[1],g.x+m[4])
        for x=math.floor(g.x),math.ceil(g.x+m[4])-1 do
            local hits=row.columns[x]
            if not hits then hits={} row.columns[x]=hits end
            table.insert(hits,g)
        end
        table.insert(result.characters,g)
        pen+=m[1]+gap
    end
    for _,line in result.lines do result.width=math.max(result.width,line.width-line.left) end
    for _,line in result.lines do
        line.offset=(result.width-line.width+line.left)*l.align/2-line.left
    end
    result.height=#result.lines*lineHeight
    return result
end

local function build(l)
    if not mappings then
        mappings=reskate.package.read_json("art/lettering/layout.json") or {}
    end
    local compose,forms=mappings.compose or {},mappings.arabic or {}
    local groups={}
    for _,cp in utf8.codes(l.text) do
        local char=utf8.char(cp)
        local last=groups[#groups]
        if last and last.cp~=10 and (mark(cp) or cp==0xfe0e or cp==0xfe0f or compose[utf8.char(last.cp)..char]) then
            last.text..=char
            local merged=compose[utf8.char(last.cp)..char]
            if merged then last.cp=merged
            elseif mark(cp) then table.insert(last.marks,cp) end
        else table.insert(groups,{cp=cp,text=char,marks={}}) end
    end
    local missing=false
    local writing=writingLayout(l,groups)
    if writing then return writing end
    for i,g in groups do
        local cp=g.cp
        if cp==10 then continue end
        local form=forms[utf8.char(cp)]
        if form then
            local before=groups[i-1] and forms[utf8.char(groups[i-1].cp)]
            local after=groups[i+1] and forms[utf8.char(groups[i+1].cp)]
            local prev=before and before.initial and form.final
            local nextJoin=after and after.final and form.initial
            cp=(if prev and nextJoin then form.medial elseif prev then form.final elseif nextJoin then form.initial else form.isolated) or cp
        end
        local shape=glyph(l.font,cp) or (l.font~="Pixel" and glyph("Pixel",cp))
        if not shape then missing=true shape=glyph("Pixel",0xfffd) or replacement end
        g.shape=shape
        g.over={}
        for _,accent in g.marks do
            local overlay=glyph("Pixel",accent)
            if overlay then table.insert(g.over,overlay) end
        end
    end
    -- Wrap whole words when possible. Explicit line breaks always start a new line.
    local lines={{}}
    local line,used=lines[1],0
    local gap=l.spacing
    local wrap=184
    local function newline() line={} table.insert(lines,line) used=0 end
    for i,g in groups do
        if g.cp==10 then newline() continue end
        if used>0 and g.cp~=32 then
            local needed=g.shape.width
            if groups[i-1] and groups[i-1].cp==32 then
                for j=i+1,#groups do
                    local following=groups[j]
                    if following.cp==32 or following.cp==10 then break end
                    needed+=following.shape.width+gap
                    if needed>wrap then break end
                end
            end
            if used+math.min(needed,wrap)>wrap then newline() end
        end
        table.insert(line,g)
        used+=g.shape.width+gap
    end
    local result={lines={},width=1,height=#lines*16,characters={},missing=missing}
    for i,logical in lines do
        local row={columns={},width=0}
        for _,g in ordered(logical) do
            g.x,g.y=row.width,(i-1)*16
            for x=1,g.shape.width do row.columns[g.x+x]=g end
            row.width+=g.shape.width+gap
            table.insert(result.characters,g)
        end
        row.width=math.max(0,row.width-gap)
        result.width=math.max(result.width,row.width)
        result.lines[i]=row
    end
    for _,row in result.lines do
        row.offset=(result.width-row.width)*l.align/2
    end
    return result
end

function M.layout(l)
    local layout=cached[l]
    if not layout or layout.text~=l.text or layout.font~=l.font or layout.spacing~=l.spacing or layout.align~=l.align or layout.natural~=l.natural then
        layout=build(l)
        layout.text,layout.font,layout.spacing,layout.align=l.text,l.font,l.spacing,l.align
        layout.natural=l.natural
        cached[l]=layout
    end
    return layout
end

function M.sample(l,u,v)
    local layout=M.layout(l)
    local y=math.floor(v*layout.height)
    if layout.smooth then
        local row=layout.lines[math.floor(y/layout.lineHeight)+1]
        if not row then return false end
        local px=u*layout.width-row.offset
        local hits=row.columns[math.floor(px)]
        if not hits then return false end
        for _,g in hits do
            local m=g.metric
            local x,dy=math.floor(px-g.x),y-g.y
            if x>=0 and dy>=0 and x<m[4] and dy<m[5] then
                local b=layout.ink:byte(1+m[6]+dy*math.ceil(m[4]/8)+math.floor(x/8))
                if b and bit32.btest(b,2^(7-x%8)) then return true end
            end
        end
        return false
    end
    local row=layout.lines[math.floor(y/16)+1]
    if not row then return false end
    local x=math.floor(u*layout.width-row.offset)
    local g=row.columns[x+1]
    if not g then return false end
    local col=x-g.x
    local bits=g.shape.rows[y%16+1]
    if bit32.btest(bits,2^(15-col)) then return true end
    for _,accent in g.over do
        local ax=col+math.floor((accent.width-g.shape.width)/2)
        if ax>=0 and ax<accent.width and bit32.btest(accent.rows[y%16+1],2^(15-ax)) then return true end
    end
    return false
end
return M
