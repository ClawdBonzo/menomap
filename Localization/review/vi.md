# vi: review

A careful, faithful Vietnamese translation in a consistent, plain bạn register with correct public-facing medical terms (bốc hỏa, đổ mồ hôi ban đêm, tiền/hậu mãn kinh, liệu pháp hormone, progestogen, chảy máu sau mãn kinh, suy buồng trứng sớm), Apple's Vietnamese platform terms, consistent old-style diacritics (khóa, khỏe, hỏa), no exclamation marks, and every safety string complete with all hedges intact. The 'after menopause' trap does not arise: mãn kinh literally means periods have ended, and the article and safety strings say so. The umbrella word 'cơn nóng' was checked and kept: Vietnamese health sources describe night sweats as hot flashes happening at night, so 'cơn nóng' (a heat episode) covers both naturally, works as a counted noun ('3 cơn nóng', 'cơn nóng ban đêm') and in 'Tôi đang có cơn nóng', and id 668 defines it as bốc hỏa and đổ mồ hôi ban đêm; the Night sweat button starting a 'cơn nóng' reads coherently. 'Canh đêm' (keeping watch through the night) is an existing, evocative expression and works as a feature name, including 'Bật Canh đêm'. The changes are few: a date placeholder that produced 'Your 28 Sep, how was it?', the mood scale's low end, the 'Already over' button, a redundant stat label, the breathing widget's half-translated rhythm, two calqued wry lines, the Surge-button reference in setup, and in the store a subtitle that read as 'report the doctor' plus an awkward screenshot headline.

Changed 13 of about 877 entries (1%).

| id | before | after | why |
|---|---|---|---|
| 87 | Đã qua | Cơn đã qua | Button logs a surge that is already over; bare 'Đã qua' (passed) lacked a subject on the Today screen. |
| 142 | Chuỗi ngày dịu %lld ngày | Chuỗi ngày dịu: %lld ngày | 'Chuỗi ngày dịu %lld ngày' repeated 'ngày' without a break; label: value form reads cleanly. |
| 317 | %@ của bạn thế nào? | Ngày %@ thế nào? | %@ is a date ('28 thg 9'); '%@ của bạn thế nào?' gave 'Your 28 Sep how?'. |
| 337 | Hít 4 · giữ 4 · thở 4 | Hít vào 4 · giữ 4 · thở ra 4 | 'thở 4' just means 'breathe 4'; the out-breath needs 'thở ra', matching ids 132/133. |
| 339 | Lò xông hơi bên trong: đang bật | Lò xông hơi trong người: đang bật | 'bên trong' is a calque; 'trong người' is the idiomatic body-internal phrasing (cf. nóng trong người). |
| 382 | Kém | Buồn chán | This is the low end of the mood scale (Low–Great); 'Kém' (poor/weak) does not describe mood. |
| 542 | Đặt Cơn nóng chỉ cách một chạm | Đặt nút Cơn nóng chỉ cách một chạm | 'Surge' here is the button; 'Đặt Cơn nóng' read as placing a hot episode. |
| 649 | Ở lại trên iPhone của bạn | Luôn nằm trên iPhone của bạn | 'Ở lại trên iPhone' is a calque of 'stays'; natural phrasing for data remaining on the device. |
| 679 | Áo khoác vào. Áo khoác ra. | Mặc áo len vào. Cởi áo len ra. | 'Áo khoác vào. Áo khoác ra.' is a word-for-word calque; the on/off rhythm needs the verbs in Vietnamese. |
| 711 | Điều hòa: mình giữ | Điều khiển điều hòa: mình giữ | 'Điều hòa: mình giữ' (I keep the air conditioner) missed the joke; the fight is over the remote/thermostat control. |
| store.subtitle | Ghi bốc hỏa & báo cáo bác sĩ | Nhật ký bốc hỏa & ghi chú khám | 'báo cáo bác sĩ' reads as 'report (on) the doctor'; 'nhật ký bốc hỏa' is a real search phrase and 'ghi chú khám' matches the in-app term. 30 chars. |
| store.keywords | tiền,đổ mồ hôi đêm,nội tiết tố,hormone,hrt,nhật ký,triệu chứng,giấc ngủ,mất ngủ,phụ nữ,trung niên | tiền,đổ mồ hôi đêm,nội tiết tố,hormone,hrt,triệu chứng,giấc ngủ,mất ngủ,phụ nữ,trung niên,chu kỳ | 'nhật ký' moved into the subtitle, so it is replaced by 'chu kỳ' (cycle) to avoid a wasted duplicate. |
| store.screenshots.9 | Dữ liệu của bạn là *của bạn*. | Dữ liệu là *của riêng bạn*. | 'Dữ liệu của bạn là của bạn' repeats itself awkwardly; 'của riêng bạn' carries the emphasis. |

## Residual doubts

- Umbrella word kept as 'cơn nóng'. In some contexts 'nóng' can mean hot-tempered (nổi nóng), but within a menopause app the heat sense is unambiguous; the alternatives ('đợt nóng' = weather heatwave, 'cơn nóng bừng' = hot-flash specific) are worse for night sweats.
- 211 'Chạm hai lần các ngón tay để kết thúc' left as is; Apple's Vietnamese pages describe Double Tap as tapping index finger and thumb together twice, which would be too long for the Watch line.
- 576 'Đã lưu. Đã ghi lại %@ thời tiết.' is a slightly literal wry line but understandable; left.
