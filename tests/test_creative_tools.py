"""Exercise the actual stroke expansion, Blackbook frames, gallery schema and playback cleanup."""
import sys
from test_menu import run

CHECKS = r'''
online=false step()
local pattern,book,media,wall=modules.pattern,modules.blackbook,modules.media_format,modules.wall_art
local brush={mode="Mirror",x=50,y=50,angle=90,sectors=4}
local s={size=20,colour=3,xy={720,330},symmetry=brush}
local function points(t)
    local out={}
    pattern.segments(s,t,function(x,y) table.insert(out,{math.round(x),math.round(y)}) end)
    return out
end
local p=points() assert(#p==2 and p[2][1]==1328 and p[2][2]==330)
s.xy={1024,330} assert(#points()==1,"shared mirror axis doubled the stroke")
s.xy={720,330}
for _,pair in {{"Four-way",4},{"Radial mirror",8},{"Rotational",4}} do brush.mode=pair[1] assert(#points()==pair[2]) end
brush.x,brush.y,brush.angle,brush.sectors=40,60,45,3
assert(#points()==3)
s.symmetry=nil
local tile={width=512,height=256,count=3}
for _,xy in {{1,1},{511,1},{1,255},{511,255}} do s.xy=xy assert(#points(tile)==4,"missing wrapped corner") end
for _,xy in {{0,123},{511,123},{220,0},{220,255}} do s.xy=xy assert(#points(tile)==2,"missing wrapped edge") end
s.xy={508,120,4,120}
pattern.segments(s,tile,function(a,b,c,d) assert(math.abs(c-a)<=8,"seam crossed the full tile") end)
local art={version=2,name="Loop fixture",tile=tile,strokes={s},
    sound={id="spray-burst",trigger="interact",volume=30,radius=4,cooldown=2}}
art.animation={frameMs=200,frames={{strokes={s},tile=tile},{strokes={{colour=6,size=48,xy={400,225,800,710}}}}}}
local id,bytes=book.save(art)
local restored=assert(book.read(id))
assert(restored.version==3 and #restored.animation.frames==2 and restored.animation.frames[1].tile.count==3)
local asset=assert(media.fromDrawing(restored,wall))
local frames=assert(media.validate(asset,modules.imports.decode))
assert(#frames==2 and asset.frames[1]~=asset.frames[2] and restored.strokes[1].xy[1]==508)
local bad=table.clone(asset) bad.frameMs=0 assert(not media.validate(bad,modules.imports.decode))
local base={1,0,0,0,0,0,.04,0,0,-.5,0,0,2,1,-2,1}
local function mark()
    local h=reskate.effects.decal("first",base)
    return {handles={h},transform=table.clone(base)}
end
assert(asset.sound==nil and restored.sound==nil)
local player=modules.playback
local a,b=mark(),mark()
reskate.audio.play=function() error("artwork started a sound") end
for _,trigger in {"interact","approach","nearby-loop"} do
    asset.sound={id="spray-loop",trigger=trigger,radius=10,volume=60,cooldown=2}
    assert(media.validate(asset,modules.imports.decode))
    assert(media.visual(asset).sound==nil)
    focus=v(2,1,0)
    player.attach(a,frames,asset) player.attach(b,frames,asset)
    player.tick(210,wall,768)
    assert(player.handles()>0 and live[a.handles[1]].alpha==0)
    focus=v(60,1,0) player.tick(10,wall,768)
    assert(player.handles()==0 and live[a.handles[1]].alpha==1)
    player.clear()
end
player.attach(a,frames,asset)
focus=v(2,1,0) player.tick(210,wall,768)
assert(player.handles()>0)
reskate.effects.clear() -- The host retires the previous map's handles before the unload callback.
emit("level_unloading")
assert(player.handles()==0)
emit("level_loaded",map)
assert(modules.playback.handles()==0)
print("PASS: symmetry, tile boundaries, frame persistence and silent playback of legacy artwork")
'''

UI = r'''
online=false step() console.graffiti({"editor"}) step()
click(420,690) click(900,286) -- duplicate first frame
click(1610,285) click(940,450) -- draw only on frame 2
click(420,690) click(702,790)
local doc=assert(modules.blackbook.read("blackbook-0001.json"))
assert(#doc.animation.frames==2 and #doc.strokes==0 and #doc.animation.frames[2].strokes==1)
assert(doc.sound==nil)
print("PASS: frame editor duplicated, independently edited and saved a silent loop")
'''
if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "creative")
    run(sys.argv[1], UI, "frame_editor")
