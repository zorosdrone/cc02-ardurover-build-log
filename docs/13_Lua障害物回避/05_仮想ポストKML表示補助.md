# 仮想ポストKML表示補助

更新日: 2026-06-20

対象: Rover SITL、`/tmp/post-locations.scr`、KML、Google EarthなどのKMLビューア

## 目的

Rover SITLが生成する`/tmp/post-locations.scr`を、KMLビューアで確認できる表示専用ファイルへ変換する。

仮想ポストの確認は、基本的にはMAVProxyの地図で行う。

```text
script /tmp/post-locations.scr
```

Mission PlannerでKMLを読み込む手順は採用しない。現行UIでは`FLIGHT PLAN`の地図右クリックからKMLオーバーレイを読み込む操作が確認できず、この用途では機能しない。

生成した`sitl-posts.kml`は、Mission Plannerへ読み込むためではなく、Google EarthなどのKMLビューアでポスト位置を確認したり、ローカル証跡として保存したりするために使う。

> [!IMPORTANT]
> このKMLは表示専用データである。WaypointやFenceとして機体へ`WRITE`しない。

## KMLへ変換する

`/tmp/post-locations.scr`は、次のようなMAVProxy地図用コマンドで構成されている。

```text
map circle <緯度> <経度> 1 blue
```

Mission Plannerはこの`.scr`を直接読み込めないため、表示専用のKMLへ変換する。SITL起動中にWSLで実行する。

```bash
python3 - <<'PY'
from pathlib import Path
import math

src = Path("/tmp/post-locations.scr")
dst = Path.home() / "ardupilot" / "sitl-posts.kml"

out = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<kml xmlns="http://www.opengis.net/kml/2.2"><Document>',
    '<name>ArduPilot SITL Posts</name>',
    '<Style id="post"><LineStyle><color>ff0000ff</color><width>2</width></LineStyle>'
    '<PolyStyle><color>500000ff</color></PolyStyle></Style>',
]

count = 0
for line in src.read_text().splitlines():
    parts = line.split()
    if len(parts) >= 6 and parts[:2] == ["map", "circle"]:
        lat, lon, radius = map(float, parts[2:5])
        coords = []
        for i in range(25):
            angle = 2 * math.pi * i / 24
            north = radius * math.cos(angle)
            east = radius * math.sin(angle)
            lat2 = lat + north / 111320
            lon2 = lon + east / (
                111320 * math.cos(math.radians(lat))
            )
            coords.append(f"{lon2:.9f},{lat2:.9f},0")

        count += 1
        out.append(
            f'<Placemark><name>Post {count}</name><styleUrl>#post</styleUrl>'
            '<Polygon><outerBoundaryIs><LinearRing><coordinates>'
            + " ".join(coords)
            + '</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>'
        )

out.append("</Document></kml>")
dst.write_text("\n".join(out), encoding="utf-8")
print(f"Created {dst}: {count} posts")
PY
```

成功時は次のように表示される。

```text
Created /home/ardupilot/ardupilot/sitl-posts.kml: 217 posts
```

`posts`の数は、SITLのバージョン、起動地点、生成された`/tmp/post-locations.scr`の内容で変わる。ここでは0件でないことと、KMLビューアで読めるファイルが作成されたことを確認する。

Windowsのエクスプローラーで保存先を開く。

```bash
explorer.exe "$(wslpath -w ~/ardupilot)"
```

表示を更新する場合は、最新の`/tmp/post-locations.scr`から同じコマンドでKMLを再生成する。

## 関連資料

- [Rover SITL前方Rangefinder / Lua設定手順](01_RoverSITL前方Rangefinder設定手順.md)