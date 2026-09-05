"""Generate editable SVG and matching PNG wiring sheets. Requires Pillow."""
from pathlib import Path
from html import escape
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent
INK, BLUE, RED, GRAY, AMBER = '#142b43', '#1769aa', '#c33435', '#536170', '#9b6100'
FONT = 'C:/Windows/Fonts/meiryo.ttc'

class Sheet:
    def __init__(self, title, subtitle):
        self.im = Image.new('RGB', (1600, 1180), '#f4f7fb')
        self.d = ImageDraw.Draw(self.im)
        self.svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1180" viewBox="0 0 1600 1180">', '<rect width="1600" height="1180" fill="#f4f7fb"/>']
        self.text(45, 30, title, 36)
        self.text(45, 85, subtitle, 20, GRAY)
    def text(self,x,y,t,size=22,color=INK):
        f=ImageFont.truetype(FONT,size)
        assert self.d.textbbox((x,y),t,font=f,anchor='lt')[2] < 1590, t
        self.d.text((x,y),t,font=f,fill=color,anchor='lt')
        self.svg.append(f'<text x="{x}" y="{y}" font-family="Meiryo,sans-serif" font-size="{size}" fill="{color}" dominant-baseline="text-before-edge">{escape(t)}</text>')
    def rect(self,x,y,w,h,fill='#ffffff',stroke='#c9d4e0'):
        self.d.rounded_rectangle((x,y,x+w,y+h),12,fill,stroke,2)
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')
    def box(self,x,y,w,h,title,lines=(),fill='#ffffff'):
        self.rect(x,y,w,h,fill)
        self.text(x+18,y+15,title,25)
        for i,line in enumerate(lines): self.text(x+18,y+56+i*30,line,20)
    def line(self,x1,y1,x2,y2,color=BLUE,dash=False,arrow=False):
        if dash:
            import math
            length=math.hypot(x2-x1,y2-y1)
            for i in range(0,int(length),18):
                a=i/length; b=min(i+10,length)/length
                self.d.line((x1+(x2-x1)*a,y1+(y2-y1)*a,x1+(x2-x1)*b,y1+(y2-y1)*b),fill=color,width=3)
        else: self.d.line((x1,y1,x2,y2),fill=color,width=3)
        self.svg.append(f'<path d="M{x1} {y1} L{x2} {y2}" stroke="{color}" fill="none" stroke-width="3"'+(' stroke-dasharray="10 8"' if dash else '')+'/>')
        if arrow:
            import math
            a=math.atan2(y2-y1,x2-x1)
            pts=[(x2,y2),(x2-12*math.cos(a-.45),y2-12*math.sin(a-.45)),(x2-12*math.cos(a+.45),y2-12*math.sin(a+.45))]
            self.d.polygon(pts,fill=color)
            self.svg.append(f'<polygon points="{" ".join(f"{x},{y}" for x,y in pts)}" fill="{color}"/>')
    def save(self,name):
        self.text(45,1135,'2026-09-05 作成｜資料に基づく接続図・実機未検証｜端子の物理配置・縮尺を示す図ではありません',18,GRAY)
        (OUT/f'{name}.svg').write_text('\n'.join(self.svg+['</svg>']),encoding='utf-8')
        self.im.save(OUT/f'{name}.png')

s=Sheet('01  全体配線図 — CC-02 / ArduRover','基準：Pixhawk 6C Mini Model A + M10 GPS｜青＝信号を含むケーブル、赤＝電源、点線＝経路を実機確認')
s.box(45,145,360,135,'Zeee 走行用バッテリー', ['3S 2200mAh 120C（部品表）','バッテリー近くのXT60を抜く'])
s.box(610,145,380,135,'PM02 パワーモジュール',['電源の降圧＋電圧・電流検出','FC同梱品の専用6芯ケーブル'])
s.line(405,210,610,210,RED,True,True); s.text(430,170,'入力側へ',20,AMBER)
s.rect(550,355,500,555,'#e9f1fb','#7b9cbd')
s.text(575,375,'Pixhawk 6C Mini',32)
for y,t in [(445,'POWER  ← PM02'),(530,'RC IN   S / + / −'),(630,'MAIN 1   S / + / −'),(740,'MAIN 3   S / + / −'),(815,'内部：MAINの + は共通サーボ電源')]: s.text(575,y,t,23)
s.line(970,280,970,445,RED,False,True); s.text(715,305,'FC用 約5V＋検出信号',18,RED)
s.box(45,480,360,125,'RadioLink R8EF V1.6',['S.BUS / CH1 → RC IN','S・+5V・GND の3本'])
s.line(405,550,550,550,BLUE,False,True)
s.box(45,650,360,115,'DS3218 / 270°サーボ',['MAIN 1へ3線接続（所有者申告）','6V対応・必要電流は仕様照合待ち'])
s.line(550,675,405,675,BLUE,False,True)
s.box(45,840,360,165,'ESC：QuicRun WP-1060',['細い3線 → MAIN 3','赤線：BEC 6V / 3A → FCレール','太い線 → CC-02付属モーター'])
s.line(550,775,455,775); s.line(455,775,455,900); s.line(455,900,405,900,BLUE,False,True)
s.text(55,320,'ESC主電源への経路は要確認',20,AMBER)
s.text(55,353,'遮断：バッテリー近くのXT60',18,AMBER)
s.text(55,383,'PM02負荷側・隠れた線は要確認',18,AMBER)
s.text(55,420,'※未確定の主電源経路は図示省略',18,AMBER)
s.box(1170,355,385,115,'M10 GPS / Compass',['GPS1へ適合10芯ケーブル','GPSとコンパスをまとめて接続'])
s.line(1050,420,1170,420); s.text(1070,385,'GPS1',20)
s.box(1170,510,385,115,'Raspberry Pi Zero 2 WH',['TELEM1：TX / RX / GNDのみ','別積みのモバイルバッテリー給電'])
s.line(1050,570,1170,570); s.text(1060,535,'TELEM1',20)
s.box(1170,665,385,115,'TF-Luna LiDAR',['TELEM2：5V / TX / RX / GND','今回の緑線がGND。詳細は図02'])
s.line(1050,725,1170,725); s.text(1060,690,'TELEM2',20)
s.box(1170,820,385,110,'OLED（任意）',['独立I2C：4本','表示成功の記録あり。図02参照'])
s.line(1050,870,1170,870); s.text(1070,835,'I2C',20)
s.rect(460,965,1095,135,'#fff4dd','#d7aa4b')
s.text(480,982,'電源を混同しない',25,AMBER)
s.text(480,1020,'PM02 → FC本体 / ESC内蔵BEC → MAIN 3の + → MAIN 1の + → サーボ',21)
s.text(480,1055,'RC INの +5V とサーボレールの +6V は別。PiへTELEM1の5Vをつながない。',21)
s.save('ardurover-wiring-overview')

s=Sheet('02  ケーブル製作・端子対応図','番号は公式ポート定義。挿し込み面と線側では左右が反転するため、現物のPin1と導通を確認してから製作。')
def panel(y,title,left,right,rows,notes):
    s.rect(45,y,1510,350)
    s.text(65,y+15,title,28)
    s.text(70,y+65,left,21); s.text(925,y+65,right,21)
    for i,(a,b,color,direction) in enumerate(rows):
        yy=y+110+i*40
        s.text(70,yy,a,21); s.text(925,yy,b,21)
        if direction=='left': s.line(895,yy+13,600,yy+13,color,False,True)
        else: s.line(600,yy+13,895,yy+13,color,False,direction=='right')
    for i,t in enumerate(notes): s.text(70,y+278+i*29,t,19,AMBER)
panel(135,'A  Raspberry Pi — 3本だけ接続','FC：TELEM1 / JST-GH 6P','Pi：40ピンGPIO（物理番号）',[
('Pin2  TX（送信）','物理10 / GPIO15 / RX（受信）',BLUE,'right'),
('Pin3  RX（受信）','物理8 / GPIO14 / TX（送信）',BLUE,'left'),
('Pin6  GND','物理6 / GND',GRAY,'none')],
['TELEM1 Pin1（5V）・Pin4（CTS）・Pin5（RTS）は未接続。各線を別々に絶縁。',
 '別積みモバイルバッテリー → Pi電源入力。C25は旧部品表の記録で現物型番未確認。UARTは3.3V。'])
panel(505,'B  TF-Luna — 4本接続 / UARTモード','FC：TELEM2 / JST-GH 6P','TF-Luna：番号・今回の現物色',[
('Pin1  +5V','No.1  赤 / +5V',RED,'right'),
('Pin2  TX（送信）','No.2  青 / RXD（受信）',BLUE,'right'),
('Pin3  RX（受信）','No.3  黄 / TXD（送信）',BLUE,'left'),
('Pin6  GND','No.4  緑 / GND',GRAY,'none')],
['FC Pin4・5は未接続。TF-Luna No.5（白）・No.6（黒）も未接続にして個別絶縁。',
 '白をGNDにつなぐとI2Cモードになる。今回の黒線はGNDではない。色より番号と導通を優先。'])
s.rect(45,875,1510,225)
s.text(65,890,'C  3線コネクタと任意のOLED',28)
s.text(70,939,'RC IN：S ← R8EF S.BUS / CH1信号、+ → 受信機電源、− ↔ GND',22)
s.text(70,980,'MAIN 1 / 3：S → サーボ / ESC信号、+ ↔ サーボ電源、− ↔ GND（上下は実機印字で確認）',22)
s.text(70,1021,'I2C → OLED：Pin1 +5V → VCC、Pin2 SCL → SCL、Pin3 SDA → SDA、Pin4 GND → GND',22)
s.text(70,1060,'TX＝送信、RX＝受信、GND＝共通の基準。線の交差ではなく、端子の役割で接続を追う。',19,GRAY)
s.save('ardurover-wiring-cables')
