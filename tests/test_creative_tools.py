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
local nextVoice,starts,stops=1,0,0
local voices={}
reskate.audio.play=function(path,opts) starts+=1 nextVoice+=1 voices[nextVoice]=opts return nextVoice end
reskate.audio.stop=function(i) assert(voices[i]) voices[i]=nil stops+=1 end
reskate.audio.set=function(i,opts) assert(voices[i]) voices[i].position=opts.position end
reskate.audio.playing=function(i) return voices[i]~=nil end
local player=modules.playback
local a,b=mark(),mark()
player.attach(a,frames,asset) player.attach(b,frames,asset)
player.tick(210,wall,768,true)
assert(starts==1 and player.handles()>0 and live[a.handles[1]].alpha==0,"independent animation or interact failed")
player.tick(1,wall,768,true) assert(starts==1,"overlapping sound")
focus=v(60,1,0) player.tick(10,wall,768,false)
assert(stops==1 and player.handles()==0 and live[a.handles[1]].alpha==1)
player.clear()
focus=v(2,1,0)
for _,trigger in {"approach","nearby-loop"} do
    asset.sound.trigger=trigger
    player.attach(a,frames,asset)
    local initial=starts
    player.tick(0,wall,768,false) player.tick(10,wall,768,false)
    assert(starts==initial+1 and voices[nextVoice].loop==(trigger=="nearby-loop"))
    a.transform[13]=3 player.tick(10,wall,768,false) assert(voices[nextVoice].position.x==3)
    assert(player.setVolume(0)) player.tick(10,wall,768,false)
    assert(next(voices)==nil)
    assert(player.setVolume(100)) player.remove(a) assert(player.handles()==0)
end
print("PASS: mirrors and rotation, shifted origins, all eight tile boundaries, version 3 round trip, two animated instances, interaction/approach/loop, movement, mute, clean removal")
'''

UI = r'''
online=false step() console.graffiti({"editor"}) step()
click(420,690) click(900,286) -- duplicate first frame
click(1610,285) click(940,450) -- draw only on frame 2
click(420,690) click(702,790)
local doc=assert(modules.blackbook.read("blackbook-0001.json"))
assert(#doc.animation.frames==2 and #doc.strokes==0 and #doc.animation.frames[2].strokes==1)
click(1510,408) click(685,786)
doc=assert(modules.blackbook.read("blackbook-0001.json"))
assert(doc.sound.id=="spray-burst")
print("PASS: real frame editor callbacks duplicated a frame, edited it independently, assigned sound and saved")
'''
if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "creative")
    run(sys.argv[1], UI, "frame_editor")
