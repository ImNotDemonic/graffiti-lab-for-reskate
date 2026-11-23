-- Dock geometry is in 1080-line design pixels. ReSkate scales font sizes by viewport height.
local dock = {ink="#F2EFE9", muted="#AAA7A1", blaze="#FF5A1F", dark="#101113", panel="#0D0E10F0"}
-- Wall Paint and the editor draw their own HUDs. Both use this native screen
-- for input capture so the plugin stays within ReSkate's four-screen limit.
local editingScreen
function dock.editingScreen()
    if not editingScreen then
        editingScreen="Graffiti Lab Studio"
        reskate.ui.screen(editingScreen,function() end,{panel=false})
    end
    return editingScreen
end
local extraTitles={["Public Artworks"]=244,["Artwork Library"]=300,["Reshape Artwork"]=356,["Map Placements"]=412}
local titles = {
    ["Graffiti"]={0,3.48}, ["Lab"]={1,1.50}, ["Premade Art"]={2,4.75},
    ["Custom Editor"]={3,5.65}, ["Wall Painting"]={4,5.15}, ["Saved Gallery"]={5,5.6},
    ["Settings"]={6,3.1}, ["Place on Wall"]={7,5.25}, ["Save to Blackbook"]={8,7.1},
}

function dock.draw(d)
    local screen=d:size()
    local scale=math.min(screen.y/1080,screen.x/576)
    local u={scale=scale, width=screen.x/scale, height=screen.y/scale}
    function u.p(x,y) return vector.create(x*scale,y*scale,0) end
    function u.rect(x,y,w,h,c) d:rect(u.p(x,y),u.p(x+w,y+h),{colour=c,fill=true}) end
    function u.border(x,y,w,h,c) d:rect(u.p(x,y),u.p(x+w,y+h),{colour=c,fill=false,thickness=1}) end
    function u.text(x,y,value,size,colour,font,align)
        d:text(u.p(x,y),value,{font=font or "body",size=size,colour=colour or dock.ink,align=align or "left",shadow=false})
    end
    function u.art(x,y,w,h,l,t,r,b,c)
        d:image("art/menu-headings-081.png",u.p(x,y),u.p(x+w,y+h),{uv={l/512,t/512,r/512,b/512},colour=c or "#FFFFFF"})
    end
    function u.heading(x,y,label,height,c)
        local top=extraTitles[label]
        if top then u.art(x,y,height*6.0,height,310,top,510,top+50,c or dock.ink) return end
        local item=titles[label]
        if not item then u.text(x,y,string.upper(label),height,c or dock.ink,"heading") return end
        local t=2+item[1]*56
        u.art(x,y,height*item[2],height,2,t,302,t+50,c or dock.ink)
    end
    function u.rule(x,y,w) u.art(x,y,w,12,310,212,510,223) end
    function u.header(name)
        u.rect(0,0,576,u.height,dock.panel)
        u.border(36,37,62,23,"#46474A")
        u.text(67,39,"← Esc",14,dock.ink,"bold","centre")
        u.text(109,39,"GRAFFITI LAB   /   "..string.upper(name),13,dock.muted,"bold")
        u.heading(36,80,name,43)
        u.rule(36,136,152)
    end
    return u
end

function dock.inside(x,y,l,t,w,h) return x>=l and x<l+w and y>=t and y<t+h end
function dock.buttons()
    local pad=reskate.input.gamepad()
    return if pad then pad.buttons else {}
end
return dock
