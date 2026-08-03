# RpanionとMission Plannerの手動映像運用

## 結論

Roverの映像は、RpanionからRTSPで配信し、Mission Plannerの`Set GStreamer Source`へGStreamerパイプラインを手動設定して表示する。

MAVLinkの自動検出は使用しない。2026-08-03の実機確認では、Mission Plannerからの`CAMERA_INFORMATION`要求とRpanionの応答までは確認できたが、`VIDEO_STREAM_INFORMATION`要求へ進まず、`Detected Streams`にカメラが表示されなかった。

## 確認済み構成

| 項目 | 設定・値 |
| --- | --- |
| Pi | Raspberry Pi Zero 2 W / `pizero2` |
| カメラ | CSI Port Camera / OV5647 |
| Rpanion | v0.11.0 |
| 配信方式 | RTSP |
| 解像度 | 1280×720 |
| フレームレート | 10 fps |
| 最大ビットレート | 1100 kbps |
| LAN側Pi IP | `192.168.188.139`（2026-08-03確認時） |
| Tailscale側Pi IP | `100.67.15.67`（2026-08-03確認時） |
| RTSPポート | `8554` |
| RTSPパス | `basesoci2c0muxi2c1ov564736` |

IPアドレスは変更される可能性がある。接続できない場合は、Rpanion管理画面の接続文字列または現在のネットワーク設定で確認する。

## 1. Rpanionで配信を開始する

Rpanion Web UIの`Video Streaming`を開き、次のように設定する。

1. `Streaming Mode`: `RTSP (multiple clients can connect to stream)`
2. `Device`: `CSI Port Camera (ov5647)`
3. `Resolution`: `1280x720`
4. `Rotation`: `0°`
5. `Maximum Bitrate`: `1100 kbps`
6. `Framerate`: `10 fps`
7. `Enable camera heartbeats`: オフ
8. `Start Streaming`を押す

ボタンが`Stop Streaming`に変われば、Rpanionは配信中である。

`Enable camera heartbeats`をオフにするには、配信中の場合はいったん`Stop Streaming`を押し、チェックを外してから再び`Start Streaming`を押す。手動運用ではMAVLinkカメラ広告は不要である。

## 2. RTSP単体で配信を確認する

Mission Plannerで映像が出ない場合は、先にVLCでRTSP配信を確認する。

### RoverとPCが同じLANの場合

```text
rtsp://192.168.188.139:8554/basesoci2c0muxi2c1ov564736
```

### Tailscale経由の場合

```text
rtsp://100.67.15.67:8554/basesoci2c0muxi2c1ov564736
```

VLCでは`Media` → `Open Network Stream`を開き、上記URLを入力する。VLCでも映像が出ない場合はMission Plannerの問題ではなく、Rpanionの配信状態またはネットワークを確認する。

## 3. Mission Plannerへ手動設定する

Mission Plannerの`Flight Data`画面でHUDを右クリックし、`Video` → `Set GStreamer Source`を開く。

### RoverとPCが同じLANの場合

次の文字列を1行で入力する。

```text
rtspsrc location=rtsp://192.168.188.139:8554/basesoci2c0muxi2c1ov564736 latency=0 is-live=True ! queue ! application/x-rtp ! rtph264depay ! avdec_h264 ! videoconvert ! video/x-raw,format=BGRA ! appsink name=outsink
```

### Tailscale経由の場合

```text
rtspsrc location=rtsp://100.67.15.67:8554/basesoci2c0muxi2c1ov564736 latency=0 is-live=True ! queue ! application/x-rtp ! rtph264depay ! avdec_h264 ! videoconvert ! video/x-raw,format=BGRA ! appsink name=outsink
```

`127.0.0.1`の接続文字列はPi自身の中だけで有効であり、Windows PC上のMission Plannerからは使用しない。

## 4. 通常の起動手順

1. RoverとPiの電源を入れる。
2. Rpanion Web UIの`Video Streaming`で、ボタンが`Stop Streaming`になっていることを確認する。
3. `Start Streaming`が表示されている場合は、ボタンを押して配信を開始する。
4. Mission Plannerを起動し、RoverのMAVLinkへ接続する。
5. HUDに映像が出ない場合は、`Set GStreamer Source`で使用中のネットワークに合った文字列を再設定する。
6. 映像の向き、遅延、停止がないことを確認する。

映像表示の成功は、GPS、Arm可否、Roverの走行可否の証明にはならない。Mission PlannerのHUDに`No GPS`や`Not Ready to Arm`が表示される場合は、映像とは別に車両側の状態を確認する。

## 5. 映像が出ない場合

| 症状 | 確認内容 |
| --- | --- |
| Rpanionが`Start Streaming`のまま | ボタンを押し、`Stop Streaming`表示に変わるか確認する |
| VLCでも映像が出ない | PiのIP、ポート`8554`、RTSPパス、PCとPiの経路を確認する |
| VLCでは出るがMission Plannerで出ない | GStreamer文字列全体、IP、`appsink name=outsink`を確認する |
| `Detected Streams`が空 | 自動検出は使用せず、`Set GStreamer Source`で手動設定する |
| 再起動後だけ出ない | Rpanionの配信開始を確認し、Mission Plannerに文字列を再設定する |

## 6. 停止手順

1. Mission Plannerの映像表示を終了する。
2. 配信を止める必要がある場合は、Rpanionで`Stop Streaming`を押す。
3. CSIケーブルを抜き差しする場合は、必ずPiをシャットダウンして電源を外す。

## 7. 自動検出を使用しない理由

2026-08-03の確認結果は次のとおり。

- Rpanionの`Enable camera heartbeats`を有効化し、広告IPに`192.168.188.139`を設定した。
- Mission Plannerの`VideoStreamSelector`で`Detected Streams`が空だった。
- RpanionログでMission Plannerからのカメラ情報要求を受信し、`CameraInformation`を返していることを確認した。
- Rpanionログに`VideoStreamInformation`要求への応答は出力されなかった。
- 手動のGStreamer文字列ではMission PlannerのHUDへ映像を表示できた。

したがって、カメラ、RTSP配信、PCからPiへのネットワークは正常であり、自動検出だけをRpanion v0.11.0とMission Planner 1.3.83間の未解決の互換性問題として切り離す。

## セキュリティ上の注意

RpanionのRTSP配信には、上記URL自体にユーザー名やパスワードが含まれていない。ポート`8554`を公開インターネットへ直接公開せず、同一LANまたはTailscale経由で使用する。
