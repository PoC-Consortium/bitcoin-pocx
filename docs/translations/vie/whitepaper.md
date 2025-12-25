# Bitcoin-PoCX: Đồng thuận Tiết kiệm Năng lượng cho Bitcoin Core

**Phiên bản**: 2.0 Bản nháp
**Ngày**: Tháng 12 năm 2025
**Tổ chức**: Proof of Capacity Consortium

---

## Tóm tắt

Đồng thuận Proof-of-Work (PoW) của Bitcoin cung cấp bảo mật mạnh mẽ nhưng tiêu thụ năng lượng đáng kể do tính toán hash liên tục theo thời gian thực. Chúng tôi trình bày Bitcoin-PoCX, một fork Bitcoin thay thế PoW bằng Proof of Capacity (PoC), trong đó thợ đào tính toán trước và lưu trữ các tập hash lớn trên đĩa trong quá trình tạo plot và sau đó đào bằng cách thực hiện các tra cứu nhẹ thay vì hash liên tục. Bằng cách chuyển việc tính toán từ giai đoạn đào sang giai đoạn tạo plot một lần, Bitcoin-PoCX giảm đáng kể mức tiêu thụ năng lượng đồng thời cho phép đào trên phần cứng phổ thông, hạ thấp rào cản tham gia và giảm thiểu áp lực tập trung hóa vốn có trong PoW bị thống trị bởi ASIC, tất cả đồng thời bảo toàn các giả định bảo mật và hành vi kinh tế của Bitcoin.

Triển khai của chúng tôi giới thiệu một số đổi mới quan trọng:
(1) Định dạng plot được gia cố loại bỏ tất cả các tấn công đánh đổi thời gian-bộ nhớ đã biết trong các hệ thống PoC hiện có, đảm bảo năng lực đào hiệu quả vẫn tỷ lệ nghiêm ngặt với dung lượng lưu trữ cam kết;
(2) Thuật toán Time-Bending biến đổi phân phối deadline từ mũ sang chi bình phương, giảm variance thời gian khối mà không thay đổi trung bình;
(3) Cơ chế ủy quyền forging dựa trên OP_RETURN cho phép đào pool không giám sát; và
(4) Mở rộng nén động, tăng độ khó tạo plot phù hợp với lịch trình halving để duy trì biên độ bảo mật dài hạn khi phần cứng cải thiện.

Bitcoin-PoCX duy trì kiến trúc Bitcoin Core thông qua các sửa đổi tối thiểu, được đánh dấu tính năng, cô lập logic PoC khỏi mã đồng thuận hiện có. Hệ thống bảo toàn chính sách tiền tệ của Bitcoin bằng cách nhắm mục tiêu khoảng khối 120 giây và điều chỉnh trợ cấp khối xuống 10 BTC. Trợ cấp giảm bù đắp cho việc tăng tần suất khối gấp năm lần, giữ tỷ lệ phát hành dài hạn phù hợp với lịch trình ban đầu của Bitcoin và duy trì nguồn cung tối đa ~21 triệu.

---

## 1. Giới thiệu

### 1.1 Động lực

Đồng thuận Proof-of-Work (PoW) của Bitcoin đã được chứng minh an toàn hơn một thập kỷ, nhưng với chi phí đáng kể: thợ đào phải liên tục tiêu tốn tài nguyên tính toán, dẫn đến tiêu thụ năng lượng cao. Ngoài những lo ngại về hiệu quả, còn có động lực rộng hơn: khám phá các cơ chế đồng thuận thay thế duy trì bảo mật đồng thời hạ thấp rào cản tham gia. PoC cho phép hầu như bất kỳ ai có phần cứng lưu trữ phổ thông đều có thể đào hiệu quả, giảm áp lực tập trung hóa thấy trong đào PoW bị thống trị bởi ASIC.

Proof of Capacity (PoC) đạt được điều này bằng cách suy ra năng lực đào từ cam kết lưu trữ thay vì tính toán liên tục. Thợ đào tính toán trước các tập hash lớn được lưu trên đĩa - plot - trong giai đoạn tạo plot một lần. Đào sau đó bao gồm các tra cứu nhẹ, giảm đáng kể việc sử dụng năng lượng đồng thời bảo toàn các giả định bảo mật của đồng thuận dựa trên tài nguyên.

### 1.2 Tích hợp với Bitcoin Core

Bitcoin-PoCX tích hợp đồng thuận PoC vào Bitcoin Core thay vì tạo blockchain mới. Cách tiếp cận này tận dụng bảo mật đã được chứng minh của Bitcoin Core, ngăn xếp mạng trưởng thành và công cụ được áp dụng rộng rãi, đồng thời giữ các sửa đổi tối thiểu và được đánh dấu tính năng. Logic PoC được cô lập khỏi mã đồng thuận hiện có, đảm bảo chức năng cốt lõi - xác thực khối, hoạt động ví, định dạng giao dịch - phần lớn không thay đổi.

### 1.3 Mục tiêu Thiết kế

**Bảo mật**: Giữ độ mạnh mẽ tương đương Bitcoin; tấn công yêu cầu dung lượng lưu trữ đa số.

**Hiệu quả**: Giảm tải tính toán liên tục xuống mức I/O đĩa.

**Khả năng Tiếp cận**: Cho phép đào với phần cứng phổ thông, hạ thấp rào cản gia nhập.

**Tích hợp Tối thiểu**: Giới thiệu đồng thuận PoC với footprint sửa đổi tối thiểu.

---

## 2. Bối cảnh: Proof of Capacity

### 2.1 Lịch sử

Proof of Capacity (PoC) được giới thiệu bởi Burstcoin vào năm 2014 như một giải pháp thay thế tiết kiệm năng lượng cho Proof-of-Work (PoW). Burstcoin chứng minh rằng năng lực đào có thể được suy ra từ lưu trữ cam kết thay vì hash liên tục theo thời gian thực: thợ đào tính toán trước các tập dữ liệu lớn ("plot") một lần và sau đó đào bằng cách đọc các phần nhỏ, cố định của chúng.

Các triển khai PoC ban đầu chứng minh khái niệm khả thi nhưng cũng tiết lộ rằng định dạng plot và cấu trúc mật mã là quan trọng cho bảo mật. Nhiều đánh đổi thời gian-bộ nhớ cho phép kẻ tấn công đào hiệu quả với ít lưu trữ hơn những người tham gia trung thực. Điều này nhấn mạnh rằng bảo mật PoC phụ thuộc vào thiết kế plot - không chỉ đơn thuần là sử dụng lưu trữ như một tài nguyên.

Di sản của Burstcoin đã thiết lập PoC như một cơ chế đồng thuận thực tế và cung cấp nền tảng mà PoCX xây dựng dựa trên.

### 2.2 Khái niệm Cốt lõi

Đào PoC dựa trên các tệp plot lớn, được tính toán trước, lưu trên đĩa. Các plot này chứa "tính toán đông lạnh": hash tốn kém được thực hiện một lần trong quá trình tạo plot, và đào sau đó bao gồm đọc đĩa nhẹ và xác minh đơn giản. Các yếu tố cốt lõi bao gồm:

**Nonce:**
Đơn vị cơ bản của dữ liệu plot. Mỗi nonce chứa 4096 scoop (tổng cộng 256 KiB) được tạo qua Shabal256 từ địa chỉ thợ đào và chỉ số nonce.

**Scoop:**
Một đoạn 64-byte bên trong một nonce. Với mỗi khối, mạng xác định chọn một chỉ số scoop (0-4095) dựa trên chữ ký sinh của khối trước. Chỉ scoop này cho mỗi nonce phải được đọc.

**Chữ ký Sinh:**
Một giá trị 256-bit được suy ra từ khối trước. Nó cung cấp entropy cho việc chọn scoop và ngăn thợ đào dự đoán các chỉ số scoop tương lai.

**Warp:**
Một nhóm cấu trúc gồm 4096 nonce (1 GiB). Warp là đơn vị liên quan cho các định dạng plot kháng nén.

### 2.3 Quy trình Đào và Pipeline Chất lượng

Đào PoC bao gồm một bước tạo plot một lần và một quy trình nhẹ cho mỗi khối:

**Thiết lập Một lần:**
- Tạo plot: Tính các nonce qua Shabal256 và ghi chúng vào đĩa.

**Đào Mỗi Khối:**
- Chọn scoop: Xác định chỉ số scoop từ chữ ký sinh.
- Quét plot: Đọc scoop đó từ tất cả nonce trong các plot của thợ đào.

**Pipeline Chất lượng:**
- Chất lượng thô: Hash mỗi scoop với chữ ký sinh sử dụng Shabal256Lite để có được giá trị chất lượng 64-bit (thấp hơn là tốt hơn).
- Deadline: Chuyển đổi chất lượng thành deadline sử dụng base target (tham số được điều chỉnh theo độ khó đảm bảo mạng đạt khoảng khối mục tiêu): `deadline = quality / base_target`
- Deadline được bend: Áp dụng biến đổi Time-Bending để giảm variance đồng thời bảo toàn thời gian khối kỳ vọng.

**Forging Khối:**
Thợ đào có deadline (được bend) ngắn nhất forge khối tiếp theo khi thời gian đó đã trôi qua.

Không giống PoW, gần như tất cả tính toán xảy ra trong quá trình tạo plot; đào hoạt động chủ yếu bị giới hạn bởi đĩa và tiêu thụ năng lượng rất thấp.

### 2.4 Các Lỗ hổng Đã biết trong Các Hệ thống Trước

**Lỗi Phân phối POC1:**
Định dạng POC1 Burstcoin gốc thể hiện thiên lệch cấu trúc: các scoop chỉ số thấp rẻ hơn đáng kể để tính toán lại ngay lập tức so với các scoop chỉ số cao. Điều này giới thiệu đánh đổi thời gian-bộ nhớ không đồng đều, cho phép kẻ tấn công giảm yêu cầu lưu trữ cho các scoop đó và phá vỡ giả định rằng tất cả dữ liệu tính toán trước đều tốn kém như nhau.

**Tấn công Nén XOR (POC2):**
Trong POC2, kẻ tấn công có thể lấy bất kỳ tập 8192 nonce nào và phân vùng chúng thành hai khối 4096 nonce (A và B). Thay vì lưu cả hai khối, kẻ tấn công chỉ lưu cấu trúc được suy ra: `A XOR transpose(B)`, trong đó transpose hoán đổi chỉ số scoop và nonce - scoop S của nonce N trong khối B trở thành scoop N của nonce S.

Trong quá trình đào, khi scoop S của nonce N được cần, kẻ tấn công tái tạo nó bằng cách:
1. Đọc giá trị XOR đã lưu tại vị trí (S, N)
2. Tính nonce N từ khối A để có scoop S
3. Tính nonce S từ khối B để có scoop N đã chuyển vị
4. XOR cả ba giá trị để khôi phục scoop 64-byte gốc

Điều này giảm lưu trữ 50%, trong khi chỉ yêu cầu hai tính toán nonce cho mỗi tra cứu - chi phí thấp hơn nhiều so với ngưỡng cần thiết để thực thi tính toán trước đầy đủ. Tấn công khả thi vì tính một hàng (một nonce, 4096 scoop) là rẻ, trong khi tính một cột (một scoop đơn qua 4096 nonce) sẽ yêu cầu tái tạo tất cả nonce. Cấu trúc transpose phơi bày sự mất cân bằng này.

Điều này chứng minh nhu cầu về định dạng plot ngăn chặn tái kết hợp có cấu trúc như vậy và loại bỏ đánh đổi thời gian-bộ nhớ cơ bản. Phần 3.3 mô tả cách PoCX giải quyết và khắc phục điểm yếu này.

### 2.5 Chuyển đổi sang PoCX

Các hạn chế của các hệ thống PoC trước đó làm rõ rằng đào lưu trữ an toàn, công bằng và phi tập trung phụ thuộc vào các cấu trúc plot được thiết kế cẩn thận. Bitcoin-PoCX giải quyết các vấn đề này với định dạng plot được gia cố, phân phối deadline được cải thiện và các cơ chế cho đào pool phi tập trung - được mô tả trong phần tiếp theo.

---

## 3. Định dạng Plot PoCX

### 3.1 Xây dựng Nonce Cơ sở

Một nonce là cấu trúc dữ liệu 256 KiB được suy ra xác định từ ba tham số: payload địa chỉ 20-byte, seed 32-byte và chỉ số nonce 64-bit.

Xây dựng bắt đầu bằng cách kết hợp các input này và hash chúng với Shabal256 để tạo hash ban đầu. Hash này là điểm bắt đầu cho quy trình mở rộng lặp: Shabal256 được áp dụng lặp đi lặp lại, với mỗi bước phụ thuộc vào dữ liệu đã tạo trước đó, cho đến khi toàn bộ buffer 256 KiB được lấp đầy. Quy trình chuỗi này đại diện cho công việc tính toán được thực hiện trong quá trình tạo plot.

Bước khuếch tán cuối cùng hash buffer đã hoàn thành và XOR kết quả qua tất cả byte. Điều này đảm bảo rằng toàn bộ buffer đã được tính và thợ đào không thể bỏ qua việc tính toán. Shuffle POC2 sau đó được áp dụng, hoán đổi nửa dưới và nửa trên của mỗi scoop để đảm bảo tất cả scoop yêu cầu nỗ lực tính toán tương đương.

Nonce cuối cùng bao gồm 4096 scoop mỗi scoop 64 byte và tạo thành đơn vị cơ bản được sử dụng trong đào.

### 3.2 Bố cục Plot Căn chỉnh SIMD

Để tối đa hóa throughput trên phần cứng hiện đại, PoCX tổ chức dữ liệu nonce trên đĩa để tạo điều kiện xử lý vector hóa. Thay vì lưu mỗi nonce tuần tự, PoCX căn chỉnh các word 4-byte tương ứng qua nhiều nonce liên tiếp. Điều này cho phép một lần lấy bộ nhớ đơn cung cấp dữ liệu cho tất cả các lane SIMD, giảm thiểu cache miss và loại bỏ overhead scatter-gather.

```
Bố cục truyền thống:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Bố cục SIMD PoCX:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Bố cục này có lợi cho cả thợ đào CPU và GPU, cho phép đánh giá scoop song song, throughput cao đồng thời giữ mẫu truy cập scalar đơn giản cho xác minh đồng thuận. Nó đảm bảo rằng đào bị giới hạn bởi băng thông lưu trữ thay vì tính toán CPU, duy trì bản chất tiêu thụ năng lượng thấp của Proof of Capacity.

### 3.3 Cấu trúc Warp và Mã hóa XOR-Transpose

Một warp là đơn vị lưu trữ cơ bản trong PoCX, bao gồm 4096 nonce (1 GiB). Định dạng không nén, được gọi là X0, chứa các nonce cơ sở chính xác như được tạo bởi xây dựng trong Phần 3.1.

**Mã hóa XOR-Transpose (X1)**

Để loại bỏ các đánh đổi thời gian-bộ nhớ cấu trúc có trong các hệ thống PoC trước đó, PoCX suy ra định dạng đào được gia cố, X1, bằng cách áp dụng mã hóa XOR-transpose cho các cặp warp X0.

Để xây dựng scoop S của nonce N trong một X1 warp:

1. Lấy scoop S của nonce N từ X0 warp đầu tiên (vị trí trực tiếp)
2. Lấy scoop N của nonce S từ X0 warp thứ hai (vị trí chuyển vị)
3. XOR hai giá trị 64-byte để có X1 scoop

Bước chuyển vị hoán đổi chỉ số scoop và nonce. Theo thuật ngữ ma trận - trong đó hàng đại diện cho scoop và cột đại diện cho nonce - nó kết hợp phần tử tại vị trí (S, N) trong warp đầu tiên với phần tử tại (N, S) trong warp thứ hai.

**Tại sao Điều này Loại bỏ Bề mặt Tấn công Nén**

XOR-transpose liên kết mỗi scoop với toàn bộ hàng và toàn bộ cột của dữ liệu X0 cơ sở. Khôi phục một X1 scoop đơn lẻ do đó yêu cầu truy cập dữ liệu trải rộng trên tất cả 4096 chỉ số scoop. Bất kỳ nỗ lực nào để tính toán dữ liệu bị thiếu sẽ yêu cầu tái tạo 4096 nonce đầy đủ, thay vì một nonce đơn lẻ - loại bỏ cấu trúc chi phí bất đối xứng bị khai thác bởi tấn công XOR cho POC2 (Phần 2.4).

Kết quả là, lưu trữ đầy đủ X1 warp trở thành chiến lược khả thi duy nhất về mặt tính toán cho thợ đào, đóng đánh đổi thời gian-bộ nhớ bị khai thác trong các thiết kế trước đó.

### 3.4 Bố cục Đĩa

Các tệp plot PoCX bao gồm nhiều X1 warp liên tiếp. Để tối đa hóa hiệu quả hoạt động trong quá trình đào, dữ liệu trong mỗi tệp được tổ chức theo scoop: tất cả dữ liệu scoop 0 từ mọi warp được lưu tuần tự, tiếp theo là tất cả dữ liệu scoop 1, v.v., đến scoop 4095.

**Sắp xếp scoop tuần tự** này cho phép thợ đào đọc dữ liệu hoàn chỉnh cần thiết cho một scoop được chọn trong một lần truy cập đĩa tuần tự đơn lẻ, giảm thiểu thời gian seek và tối đa hóa throughput trên thiết bị lưu trữ phổ thông.

Kết hợp với mã hóa XOR-transpose của Phần 3.3, bố cục này đảm bảo tệp vừa **được gia cố cấu trúc** vừa **hiệu quả hoạt động**: sắp xếp scoop tuần tự hỗ trợ I/O đĩa tối ưu, trong khi bố cục bộ nhớ căn chỉnh SIMD (xem Phần 3.2) cho phép đánh giá scoop song song, throughput cao.

### 3.5 Mở rộng Proof-of-Work (Xn)

PoCX triển khai tính toán trước có thể mở rộng thông qua khái niệm các cấp độ mở rộng, ký hiệu Xn, để thích ứng với hiệu năng phần cứng đang phát triển. Định dạng X1 baseline đại diện cho cấu trúc warp được gia cố XOR-transpose đầu tiên.

Mỗi cấp độ mở rộng Xn tăng proof-of-work được nhúng trong mỗi warp theo cấp số mũ so với X1: công việc yêu cầu tại cấp độ Xn là 2^(n-1) lần của X1. Chuyển đổi từ Xn sang Xn+1 tương đương về mặt hoạt động với việc áp dụng XOR qua các cặp warp liền kề, từng bước nhúng thêm proof-of-work mà không thay đổi kích thước plot cơ bản.

Các tệp plot hiện có được tạo ở các cấp độ mở rộng thấp hơn vẫn có thể được sử dụng để đào, nhưng chúng đóng góp ít công việc hơn tỷ lệ thuận với proof-of-work được nhúng thấp hơn của chúng. Cơ chế này đảm bảo các plot PoCX vẫn an toàn, linh hoạt và cân bằng kinh tế theo thời gian.

### 3.6 Chức năng Seed

Tham số seed cho phép nhiều plot không chồng chéo cho mỗi địa chỉ mà không cần phối hợp thủ công.

**Vấn đề (POC2)**: Thợ đào phải theo dõi thủ công các phạm vi nonce qua các tệp plot để tránh chồng chéo. Các nonce chồng chéo lãng phí lưu trữ mà không tăng năng lực đào.

**Giải pháp**: Mỗi cặp `(address, seed)` định nghĩa một không gian khóa độc lập. Các plot với seed khác nhau không bao giờ chồng chéo, bất kể phạm vi nonce. Thợ đào có thể tạo plot tự do mà không cần phối hợp.

---

## 4. Đồng thuận Proof of Capacity

PoCX mở rộng đồng thuận Nakamoto của Bitcoin với cơ chế bằng chứng dựa trên lưu trữ. Thay vì tiêu tốn năng lượng vào hash lặp đi lặp lại, thợ đào cam kết lượng lớn dữ liệu tính toán trước - plot - vào đĩa. Trong quá trình tạo khối, họ phải định vị một phần nhỏ, không thể dự đoán của dữ liệu này và biến đổi nó thành bằng chứng. Thợ đào cung cấp bằng chứng tốt nhất trong cửa sổ thời gian kỳ vọng giành quyền forge khối tiếp theo.

Chương này mô tả cách PoCX cấu trúc metadata khối, suy ra tính không thể dự đoán và biến đổi lưu trữ tĩnh thành cơ chế đồng thuận an toàn, variance thấp.

### 4.1 Cấu trúc Khối

PoCX giữ header khối kiểu Bitcoin quen thuộc nhưng giới thiệu các trường đồng thuận bổ sung cần thiết cho đào dựa trên dung lượng. Các trường này tổng hợp liên kết khối với plot đã lưu của thợ đào, độ khó của mạng và entropy mật mã định nghĩa mỗi thách thức đào.

Ở mức cao, một khối PoCX chứa: chiều cao khối, được ghi rõ ràng để đơn giản hóa xác thực theo ngữ cảnh; chữ ký sinh, nguồn entropy mới liên kết mỗi khối với khối trước; base target, đại diện độ khó mạng dưới dạng nghịch đảo (giá trị cao hơn tương ứng với đào dễ hơn); bằng chứng PoCX, xác định plot của thợ đào, cấp độ nén sử dụng khi tạo plot, nonce được chọn và chất lượng được suy ra từ đó; và khóa ký và chữ ký, chứng minh kiểm soát dung lượng được sử dụng để forge khối (hoặc khóa forging được ủy quyền).

Bằng chứng nhúng tất cả thông tin liên quan đồng thuận cần thiết cho validator để tính lại thách thức, xác minh scoop được chọn và xác nhận chất lượng kết quả. Bằng cách mở rộng thay vì thiết kế lại cấu trúc khối, PoCX vẫn phù hợp về mặt khái niệm với Bitcoin đồng thời cho phép nguồn công việc đào khác biệt cơ bản.

### 4.2 Chuỗi Chữ ký Sinh

Chữ ký sinh cung cấp tính không thể dự đoán cần thiết cho đào Proof of Capacity an toàn. Mỗi khối suy ra chữ ký sinh từ chữ ký và người ký của khối trước, đảm bảo thợ đào không thể dự đoán các thách thức tương lai hoặc tính toán trước các vùng plot thuận lợi:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Điều này tạo ra chuỗi các giá trị entropy mạnh về mật mã, phụ thuộc vào thợ đào. Vì khóa công khai của thợ đào không được biết cho đến khi khối trước được publish, không có người tham gia nào có thể dự đoán việc chọn scoop tương lai. Điều này ngăn chặn tính toán trước chọn lọc hoặc tạo plot chiến lược và đảm bảo rằng mỗi khối giới thiệu công việc đào mới thực sự.

### 4.3 Quy trình Forging

Đào trong PoCX bao gồm việc biến đổi dữ liệu đã lưu thành bằng chứng được điều khiển hoàn toàn bởi chữ ký sinh. Mặc dù quy trình là xác định, tính không thể dự đoán của chữ ký đảm bảo thợ đào không thể chuẩn bị trước và phải truy cập lặp đi lặp lại các plot đã lưu của họ.

**Suy ra Thách thức (Chọn Scoop):** Thợ đào hash chữ ký sinh hiện tại với chiều cao khối để có chỉ số scoop trong phạm vi 0-4095. Chỉ số này xác định đoạn 64-byte nào của mỗi nonce đã lưu tham gia vào bằng chứng. Vì chữ ký sinh phụ thuộc vào người ký của khối trước, việc chọn scoop chỉ được biết tại thời điểm publish khối.

**Đánh giá Bằng chứng (Tính Chất lượng):** Với mỗi nonce trong một plot, thợ đào lấy scoop được chọn và hash nó cùng với chữ ký sinh để có chất lượng - giá trị 64-bit có độ lớn xác định tính cạnh tranh của thợ đào. Chất lượng thấp hơn tương ứng với bằng chứng tốt hơn.

**Hình thành Deadline (Time Bending):** Deadline thô tỷ lệ với chất lượng và nghịch đảo với base target. Trong các thiết kế PoC legacy, các deadline này tuân theo phân phối mũ rất lệch, tạo ra các độ trễ đuôi dài không cung cấp thêm bảo mật. PoCX biến đổi deadline thô sử dụng Time Bending (Phần 4.4), giảm variance và đảm bảo khoảng khối có thể dự đoán. Khi deadline được bend đã trôi qua, thợ đào forge khối bằng cách nhúng bằng chứng và ký với khóa forging hiệu quả.

### 4.4 Time Bending

Proof of Capacity tạo ra các deadline phân phối mũ. Sau một khoảng thời gian ngắn - thường là vài chục giây - mỗi thợ đào đã xác định bằng chứng tốt nhất của họ, và bất kỳ thời gian chờ bổ sung nào chỉ đóng góp độ trễ, không phải bảo mật.

Time Bending định hình lại phân phối bằng cách áp dụng biến đổi căn bậc ba:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Hệ số scale bảo toàn thời gian khối kỳ vọng (120 giây) đồng thời giảm đáng kể variance. Các deadline ngắn được mở rộng, cải thiện lan truyền khối và an toàn mạng. Các deadline dài được nén, ngăn outlier làm chậm chuỗi.

![Phân phối Thời gian Khối](blocktime_distributions.svg)

Time Bending duy trì nội dung thông tin của bằng chứng cơ sở. Nó không sửa đổi tính cạnh tranh giữa các thợ đào; nó chỉ tái phân bổ thời gian chờ để tạo ra khoảng khối mượt mà, dễ dự đoán hơn. Triển khai sử dụng số học dấu phẩy cố định (định dạng Q42) và số nguyên 256-bit để đảm bảo kết quả xác định trên tất cả nền tảng.

### 4.5 Điều chỉnh Độ khó

PoCX điều tiết sản xuất khối sử dụng base target, thước đo độ khó nghịch đảo. Thời gian khối kỳ vọng tỷ lệ với tỷ lệ `quality / base_target`, vì vậy tăng base target tăng tốc tạo khối trong khi giảm nó làm chậm chuỗi.

Độ khó điều chỉnh mỗi khối sử dụng thời gian đo được giữa các khối gần đây so với khoảng mục tiêu. Điều chỉnh thường xuyên này là cần thiết vì dung lượng lưu trữ có thể được thêm hoặc loại bỏ nhanh chóng - không giống hashpower của Bitcoin, thay đổi chậm hơn.

Việc điều chỉnh tuân theo hai ràng buộc hướng dẫn: **Dần dần** - thay đổi mỗi khối bị giới hạn (tối đa ±20%) để tránh dao động hoặc thao túng; **Gia cố** - base target không thể vượt quá giá trị genesis, ngăn mạng giảm độ khó dưới các giả định bảo mật ban đầu.

### 4.6 Tính hợp lệ Khối

Một khối trong PoCX hợp lệ khi nó trình bày bằng chứng có nguồn gốc lưu trữ có thể xác minh nhất quán với trạng thái đồng thuận. Validator độc lập tính lại việc chọn scoop, suy ra chất lượng kỳ vọng từ nonce và metadata plot đã gửi, áp dụng biến đổi Time Bending và xác nhận thợ đào đủ điều kiện forge khối tại thời gian khai báo.

Cụ thể, một khối hợp lệ yêu cầu: deadline đã trôi qua kể từ khối cha; chất lượng đã gửi khớp chất lượng tính toán cho bằng chứng; cấp độ mở rộng đáp ứng tối thiểu mạng; chữ ký sinh khớp giá trị kỳ vọng; base target khớp giá trị kỳ vọng; chữ ký khối đến từ người ký hiệu quả; và coinbase trả cho địa chỉ của người ký hiệu quả.

---

## 5. Ủy quyền Forging

### 5.1 Động lực

Ủy quyền forging cho phép chủ sở hữu plot ủy thác quyền forge khối mà không bao giờ từ bỏ quyền sở hữu plot. Cơ chế này cho phép đào pool và thiết lập cold-storage đồng thời bảo toàn đảm bảo bảo mật của PoCX.

Trong đào pool, chủ sở hữu plot có thể ủy quyền pool forge khối thay mặt họ. Pool lắp ráp khối và phân phối phần thưởng, nhưng nó không bao giờ có quyền giám sát các plot. Ủy thác có thể đảo ngược bất cứ lúc nào, và chủ sở hữu plot vẫn tự do rời pool hoặc thay đổi cấu hình mà không cần tạo plot lại.

Ủy quyền cũng hỗ trợ tách biệt rõ ràng giữa khóa cold và hot. Khóa riêng kiểm soát plot có thể duy trì ngoại tuyến, trong khi khóa forging riêng biệt - được lưu trên máy trực tuyến - tạo khối. Do đó, việc xâm phạm khóa forging chỉ xâm phạm quyền forging, không phải quyền sở hữu. Plot vẫn an toàn và ủy quyền có thể bị thu hồi, đóng lỗ hổng bảo mật ngay lập tức.

Ủy quyền forging do đó cung cấp linh hoạt hoạt động đồng thời duy trì nguyên tắc rằng kiểm soát dung lượng đã lưu không bao giờ được chuyển cho trung gian.

### 5.2 Giao thức Ủy quyền

Ủy quyền được khai báo thông qua các giao dịch OP_RETURN để tránh tăng trưởng không cần thiết của tập UTXO. Giao dịch ủy quyền chỉ định địa chỉ plot và địa chỉ forging được ủy quyền tạo khối sử dụng dung lượng của plot đó. Giao dịch thu hồi chỉ chứa địa chỉ plot. Trong cả hai trường hợp, chủ sở hữu plot chứng minh kiểm soát bằng cách ký input chi tiêu của giao dịch.

Mỗi ủy quyền tiến triển qua chuỗi các trạng thái được định nghĩa rõ ràng (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Sau khi giao dịch ủy quyền xác nhận, hệ thống vào giai đoạn kích hoạt ngắn. Độ trễ này - 30 khối, khoảng một giờ - đảm bảo ổn định trong các cuộc đua khối và ngăn chuyển đổi nhanh bất lợi của danh tính forging. Khi khoảng kích hoạt này hết hạn, ủy quyền trở nên hoạt động và duy trì cho đến khi chủ sở hữu plot phát hành thu hồi.

Thu hồi chuyển sang khoảng độ trễ dài hơn 720 khối, khoảng một ngày. Trong thời gian này, địa chỉ forging trước đó vẫn hoạt động. Độ trễ dài hơn này cung cấp ổn định hoạt động cho pool, ngăn "nhảy ủy quyền" chiến lược và cho các nhà cung cấp cơ sở hạ tầng đủ chắc chắn để hoạt động hiệu quả. Sau khi độ trễ thu hồi hết hạn, thu hồi hoàn tất và chủ sở hữu plot tự do chỉ định khóa forging mới.

Trạng thái ủy quyền được duy trì trong cấu trúc lớp đồng thuận song song với tập UTXO và hỗ trợ dữ liệu undo để xử lý an toàn các tái tổ chức chuỗi.

### 5.3 Quy tắc Xác thực

Với mỗi khối, validator xác định người ký hiệu quả - địa chỉ phải ký khối và nhận phần thưởng coinbase. Người ký này chỉ phụ thuộc vào trạng thái ủy quyền tại chiều cao khối.

Nếu không có ủy quyền hoặc ủy quyền chưa hoàn thành giai đoạn kích hoạt, chủ sở hữu plot vẫn là người ký hiệu quả. Khi ủy quyền trở nên hoạt động, địa chỉ forging được ủy quyền phải ký. Trong quá trình thu hồi, địa chỉ forging tiếp tục ký cho đến khi độ trễ thu hồi hết hạn. Chỉ sau đó quyền mới trở về chủ sở hữu plot.

Validator thực thi rằng chữ ký khối được tạo bởi người ký hiệu quả, rằng coinbase trả cho cùng địa chỉ, và rằng tất cả chuyển đổi tuân theo các độ trễ kích hoạt và thu hồi quy định. Chỉ chủ sở hữu plot có thể tạo hoặc thu hồi ủy quyền; khóa forging không thể sửa đổi hoặc mở rộng quyền của chính chúng.

Ủy quyền forging do đó giới thiệu ủy thác linh hoạt mà không giới thiệu tin cậy. Quyền sở hữu dung lượng cơ sở luôn được neo mật mã với chủ sở hữu plot, trong khi quyền forging có thể được ủy thác, xoay vòng hoặc thu hồi khi nhu cầu hoạt động phát triển.

---

## 6. Mở rộng Động

Khi phần cứng phát triển, chi phí tính toán plot giảm so với việc đọc công việc được tính toán trước từ đĩa. Nếu không có biện pháp đối phó, kẻ tấn công cuối cùng có thể tạo bằng chứng ngay lập tức nhanh hơn thợ đào đọc công việc đã lưu, làm suy yếu mô hình bảo mật của Proof of Capacity.

Để bảo toàn biên độ bảo mật dự định, PoCX triển khai lịch trình mở rộng: cấp độ mở rộng tối thiểu yêu cầu cho plot tăng theo thời gian. Mỗi cấp độ mở rộng Xn, như được mô tả trong Phần 3.5, nhúng nhiều proof-of-work theo cấp số mũ hơn trong cấu trúc plot, đảm bảo thợ đào tiếp tục cam kết tài nguyên lưu trữ đáng kể ngay cả khi tính toán trở nên rẻ hơn.

Lịch trình phù hợp với các động cơ kinh tế của mạng, đặc biệt là halving phần thưởng khối. Khi phần thưởng mỗi khối giảm, cấp độ tối thiểu tăng dần, bảo toàn sự cân bằng giữa nỗ lực tạo plot và tiềm năng đào:

| Khoảng | Năm | Halving | Mở rộng Tối thiểu | Hệ số Công việc Plot |
|--------|-----|---------|-------------------|---------------------|
| Epoch 0 | 0-4 | 0 | X1 | 2× baseline |
| Epoch 1 | 4-12 | 1-2 | X2 | 4× baseline |
| Epoch 2 | 12-28 | 3-6 | X3 | 8× baseline |
| Epoch 3 | 28-60 | 7-14 | X4 | 16× baseline |
| Epoch 4 | 60-124 | 15-30 | X5 | 32× baseline |
| Epoch 5 | 124+ | 31+ | X6 | 64× baseline |

Thợ đào có thể tùy chọn chuẩn bị plot vượt quá mức tối thiểu hiện tại một cấp độ, cho phép họ lên kế hoạch trước và tránh nâng cấp ngay lập tức khi mạng chuyển sang epoch tiếp theo. Bước tùy chọn này không mang lại lợi thế bổ sung về xác suất khối - nó chỉ cho phép chuyển đổi hoạt động mượt mà hơn.

Các khối chứa bằng chứng dưới cấp độ mở rộng tối thiểu cho chiều cao của chúng được coi là không hợp lệ. Validator kiểm tra cấp độ mở rộng khai báo trong bằng chứng với yêu cầu mạng hiện tại trong quá trình xác thực đồng thuận, đảm bảo tất cả thợ đào tham gia đáp ứng kỳ vọng bảo mật đang phát triển.

---

## 7. Kiến trúc Đào

PoCX tách các hoạt động quan trọng đồng thuận khỏi các tác vụ tốn tài nguyên của đào, cho phép cả bảo mật và hiệu quả. Node duy trì blockchain, xác thực khối, quản lý mempool và cung cấp giao diện RPC. Thợ đào bên ngoài xử lý lưu trữ plot, đọc scoop, tính chất lượng và quản lý deadline. Sự tách biệt này giữ logic đồng thuận đơn giản và có thể kiểm toán đồng thời cho phép thợ đào tối ưu hóa cho throughput đĩa.

### 7.1 Giao diện RPC Đào

Thợ đào tương tác với node thông qua tập hợp tối thiểu các lệnh RPC. RPC get_mining_info cung cấp chiều cao khối hiện tại, chữ ký sinh, base target, deadline mục tiêu và phạm vi cấp độ mở rộng plot được chấp nhận. Sử dụng thông tin này, thợ đào tính các nonce ứng viên. RPC submit_nonce cho phép thợ đào gửi lời giải đề xuất, bao gồm định danh plot, chỉ số nonce, cấp độ mở rộng và tài khoản thợ đào. Node đánh giá submission và phản hồi với deadline tính toán nếu bằng chứng hợp lệ.

### 7.2 Forging Scheduler

Node duy trì forging scheduler, theo dõi các submission đến và chỉ giữ lời giải tốt nhất cho mỗi chiều cao khối. Các nonce đã gửi được xếp hàng với các bảo vệ tích hợp chống tràn submission hoặc tấn công từ chối dịch vụ. Scheduler chờ cho đến khi deadline tính toán hết hạn hoặc lời giải tốt hơn đến, tại thời điểm đó nó lắp ráp khối, ký sử dụng khóa forging hiệu quả và publish đến mạng.

### 7.3 Forging Phòng thủ

Để ngăn tấn công timing hoặc động cơ thao túng đồng hồ, PoCX triển khai forging phòng thủ. Nếu khối cạnh tranh đến cho cùng chiều cao, scheduler so sánh lời giải cục bộ với khối mới. Nếu chất lượng cục bộ tốt hơn, node forge ngay lập tức thay vì chờ deadline ban đầu. Điều này đảm bảo thợ đào không thể đạt được lợi thế chỉ bằng cách điều chỉnh đồng hồ cục bộ; lời giải tốt nhất luôn chiến thắng, bảo toàn công bằng và bảo mật mạng.

---

## 8. Phân tích Bảo mật

### 8.1 Mô hình Mối đe dọa

PoCX mô hình hóa các đối thủ với khả năng đáng kể nhưng bị giới hạn. Kẻ tấn công có thể cố gắng quá tải mạng với giao dịch không hợp lệ, khối không đúng định dạng hoặc bằng chứng giả để test các đường dẫn xác thực. Họ có thể tự do thao túng đồng hồ cục bộ và có thể cố gắng khai thác các trường hợp biên trong hành vi đồng thuận như xử lý timestamp, động lực điều chỉnh độ khó hoặc quy tắc tái tổ chức. Các đối thủ cũng được kỳ vọng thăm dò cơ hội viết lại lịch sử thông qua fork chuỗi có mục tiêu.

Mô hình giả định rằng không có bên đơn lẻ nào kiểm soát đa số tổng dung lượng lưu trữ mạng. Như với bất kỳ cơ chế đồng thuận dựa trên tài nguyên nào, kẻ tấn công dung lượng 51% có thể đơn phương tái tổ chức chuỗi; hạn chế cơ bản này không đặc thù cho PoCX. PoCX cũng giả định kẻ tấn công không thể tính dữ liệu plot nhanh hơn thợ đào trung thực có thể đọc từ đĩa. Lịch trình mở rộng (Phần 6) đảm bảo khoảng cách tính toán cần thiết cho bảo mật tăng theo thời gian khi phần cứng cải thiện.

Các phần tiếp theo xem xét chi tiết từng lớp tấn công chính và mô tả các biện pháp đối phó được xây dựng trong PoCX.

### 8.2 Tấn công Dung lượng

Giống PoW, kẻ tấn công với dung lượng đa số có thể viết lại lịch sử (tấn công 51%). Đạt được điều này yêu cầu có được footprint lưu trữ vật lý lớn hơn mạng trung thực - một nỗ lực tốn kém và đòi hỏi về mặt hậu cần. Khi phần cứng đã được mua, chi phí hoạt động thấp, nhưng đầu tư ban đầu tạo động cơ kinh tế mạnh để hành xử trung thực: làm suy yếu chuỗi sẽ làm hỏng giá trị của cơ sở tài sản của chính kẻ tấn công.

PoC cũng tránh vấn đề nothing-at-stake liên quan đến PoS. Mặc dù thợ đào có thể quét plot với nhiều fork cạnh tranh, mỗi lần quét tiêu tốn thời gian thực - thường theo thứ tự hàng chục giây mỗi chuỗi. Với khoảng khối 120 giây, điều này vốn dĩ giới hạn đào đa fork, và cố gắng đào nhiều fork đồng thời làm giảm hiệu năng trên tất cả. Đào fork do đó không phải là không tốn chi phí; nó bị giới hạn cơ bản bởi throughput I/O.

Ngay cả nếu phần cứng tương lai cho phép quét plot gần như tức thì (ví dụ, SSD tốc độ cao), kẻ tấn công vẫn phải đối mặt với yêu cầu tài nguyên vật lý đáng kể để kiểm soát đa số dung lượng mạng, làm cho tấn công kiểu 51% tốn kém và thách thức về mặt hậu cần.

Cuối cùng, tấn công dung lượng khó thuê hơn nhiều so với tấn công hashpower. Compute GPU có thể được mua theo yêu cầu và chuyển hướng đến bất kỳ chuỗi PoW nào ngay lập tức. Ngược lại, PoC yêu cầu phần cứng vật lý, tạo plot tốn thời gian và hoạt động I/O liên tục. Những ràng buộc này làm cho các tấn công ngắn hạn, cơ hội ít khả thi hơn nhiều.

### 8.3 Tấn công Timing

Timing đóng vai trò quan trọng hơn trong Proof of Capacity so với Proof of Work. Trong PoW, timestamp chủ yếu ảnh hưởng đến điều chỉnh độ khó; trong PoC, chúng xác định liệu deadline của thợ đào đã trôi qua hay chưa và do đó liệu khối có đủ điều kiện để forging hay không. Deadline được đo so với timestamp của khối cha, nhưng đồng hồ cục bộ của node được sử dụng để đánh giá liệu khối đến có nằm quá xa trong tương lai hay không. Vì lý do này PoCX thực thi dung sai timestamp chặt: khối không được lệch quá 15 giây so với đồng hồ cục bộ của node (so với cửa sổ 2 giờ của Bitcoin). Giới hạn này hoạt động theo cả hai hướng - khối quá xa trong tương lai bị từ chối, và node với đồng hồ chậm có thể từ chối không chính xác các khối đến hợp lệ.

Node do đó nên đồng bộ đồng hồ sử dụng NTP hoặc nguồn thời gian tương đương. PoCX cố tình tránh dựa vào nguồn thời gian nội mạng để ngăn kẻ tấn công thao túng thời gian mạng được nhận thức. Node giám sát lệch của chính họ và phát cảnh báo nếu đồng hồ cục bộ bắt đầu lệch khỏi timestamp khối gần đây.

Tăng tốc đồng hồ - chạy đồng hồ cục bộ nhanh để forge sớm hơn một chút - chỉ cung cấp lợi ích biên. Trong dung sai cho phép, forging phòng thủ (Phần 7.3) đảm bảo thợ đào với lời giải tốt hơn sẽ ngay lập tức publish khi thấy khối sớm kém hơn. Đồng hồ nhanh chỉ giúp thợ đào publish lời giải thắng sớm hơn vài giây; nó không thể chuyển bằng chứng kém thành bằng chứng thắng.

Nỗ lực thao túng độ khó qua timestamp bị giới hạn bởi giới hạn điều chỉnh ±20% mỗi khối và cửa sổ cuộn 24 khối, ngăn thợ đào ảnh hưởng có ý nghĩa đến độ khó thông qua trò chơi timing ngắn hạn.

### 8.4 Tấn công Đánh đổi Thời gian-Bộ nhớ

Đánh đổi thời gian-bộ nhớ cố gắng giảm yêu cầu lưu trữ bằng cách tính lại các phần của plot theo yêu cầu. Các hệ thống Proof of Capacity trước đó dễ bị các tấn công như vậy, đáng chú ý nhất là lỗi mất cân bằng scoop POC1 và tấn công nén XOR-transpose POC2 (Phần 2.4). Cả hai đều khai thác sự bất đối xứng trong việc tái tạo các phần nhất định của dữ liệu plot tốn kém như thế nào, cho phép đối thủ cắt giảm lưu trữ trong khi chỉ trả một hình phạt tính toán nhỏ. Ngoài ra, các định dạng plot thay thế cho PoC2 cũng có điểm yếu TMTO tương tự; ví dụ nổi bật là Chia, có định dạng plot có thể bị giảm tùy ý bởi hệ số lớn hơn 4.

PoCX loại bỏ hoàn toàn các bề mặt tấn công này thông qua xây dựng nonce và định dạng warp. Trong mỗi nonce, bước khuếch tán cuối cùng hash buffer đã tính đầy đủ và XOR kết quả qua tất cả byte, đảm bảo mọi phần của buffer phụ thuộc vào mọi phần khác và không thể bị bỏ qua. Sau đó, shuffle POC2 hoán đổi nửa dưới và nửa trên của mỗi scoop, cân bằng chi phí tính toán để khôi phục bất kỳ scoop nào.

PoCX tiếp tục loại bỏ tấn công nén XOR-transpose POC2 bằng cách suy ra định dạng X1 được gia cố, trong đó mỗi scoop là XOR của vị trí trực tiếp và vị trí chuyển vị qua các warp ghép cặp; điều này liên kết mọi scoop với toàn bộ hàng và toàn bộ cột của dữ liệu X0 cơ sở, làm cho tái tạo yêu cầu hàng nghìn nonce đầy đủ và do đó loại bỏ hoàn toàn đánh đổi thời gian-bộ nhớ bất đối xứng.

Kết quả là, lưu trữ đầy đủ plot là chiến lược khả thi duy nhất về mặt tính toán cho thợ đào. Không có shortcut đã biết nào - dù là tạo plot một phần, tái tạo chọn lọc, nén có cấu trúc hay cách tiếp cận compute-storage lai - cung cấp lợi thế có ý nghĩa. PoCX đảm bảo đào vẫn bị giới hạn nghiêm ngặt bởi lưu trữ và dung lượng phản ánh cam kết vật lý thực sự.

### 8.5 Tấn công Ủy quyền

PoCX sử dụng máy trạng thái xác định để quản lý tất cả ủy quyền plot-to-forger. Mỗi ủy quyền tiến triển qua các trạng thái được định nghĩa rõ ràng - UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED - với các độ trễ kích hoạt và thu hồi được thực thi. Điều này đảm bảo thợ đào không thể thay đổi ủy quyền tức thì để gian lận hệ thống hoặc nhanh chóng chuyển đổi quyền forging.

Vì tất cả chuyển đổi yêu cầu bằng chứng mật mã - cụ thể, chữ ký của chủ sở hữu plot có thể xác minh với input UTXO - mạng có thể tin tưởng tính hợp pháp của mỗi ủy quyền. Nỗ lực bỏ qua máy trạng thái hoặc giả mạo ủy quyền tự động bị từ chối trong quá trình xác thực đồng thuận. Tấn công replay tương tự được ngăn chặn bởi các bảo vệ replay giao dịch kiểu Bitcoin tiêu chuẩn, đảm bảo mọi hành động ủy quyền được gắn duy nhất với input chưa chi tiêu hợp lệ.

Sự kết hợp của quản trị máy trạng thái, độ trễ được thực thi và bằng chứng mật mã làm cho gian lận dựa trên ủy quyền thực tế là không thể: thợ đào không thể chiếm đoạt ủy quyền, thực hiện tái ủy quyền nhanh trong các cuộc đua khối hoặc bỏ qua lịch trình thu hồi.

### 8.6 Bảo mật Chữ ký

Chữ ký khối trong PoCX đóng vai trò liên kết quan trọng giữa bằng chứng và khóa forging hiệu quả, đảm bảo chỉ thợ đào được ủy quyền có thể tạo khối hợp lệ.

Để ngăn tấn công malleability, chữ ký bị loại khỏi tính toán hash khối. Điều này loại bỏ rủi ro chữ ký có thể thay đổi có thể làm suy yếu xác thực hoặc cho phép tấn công thay thế khối.

Để giảm thiểu vector từ chối dịch vụ, kích thước chữ ký và khóa công khai được cố định - 65 byte cho chữ ký compact và 33 byte cho khóa công khai nén - ngăn kẻ tấn công làm phình khối để kích hoạt cạn kiệt tài nguyên hoặc làm chậm lan truyền mạng.

---

## 9. Triển khai

PoCX được triển khai như mở rộng module cho Bitcoin Core, với tất cả mã liên quan chứa trong thư mục con chuyên dụng của riêng nó và được kích hoạt thông qua cờ tính năng. Thiết kế này bảo toàn tính toàn vẹn của mã gốc, cho phép PoCX được bật hoặc tắt sạch sẽ, đơn giản hóa testing, kiểm toán và đồng bộ với các thay đổi upstream.

Tích hợp chỉ chạm các điểm thiết yếu cần thiết để hỗ trợ Proof of Capacity. Header khối đã được mở rộng để bao gồm các trường đặc thù PoCX, và xác thực đồng thuận đã được điều chỉnh để xử lý bằng chứng dựa trên lưu trữ cùng với các kiểm tra Bitcoin truyền thống. Hệ thống forging, chịu trách nhiệm quản lý deadline, lập lịch và submission thợ đào, được chứa hoàn toàn trong các module PoCX, trong khi các mở rộng RPC cung cấp chức năng đào và ủy quyền cho client bên ngoài. Đối với người dùng, giao diện ví đã được cải tiến để quản lý ủy quyền thông qua giao dịch OP_RETURN, cho phép tương tác liền mạch với các tính năng đồng thuận mới.

Tất cả hoạt động quan trọng đồng thuận được triển khai trong C++ xác định không có phụ thuộc bên ngoài, đảm bảo nhất quán đa nền tảng. Shabal256 được sử dụng cho hash, trong khi Time Bending và tính chất lượng dựa vào số học dấu phẩy cố định và hoạt động 256-bit. Các hoạt động mật mã như xác minh chữ ký tận dụng thư viện secp256k1 hiện có của Bitcoin Core.

Bằng cách cô lập chức năng PoCX theo cách này, triển khai vẫn có thể kiểm toán, bảo trì và tương thích đầy đủ với phát triển Bitcoin Core đang diễn ra, chứng minh cơ chế đồng thuận dựa trên lưu trữ mới cơ bản có thể cùng tồn tại với codebase proof-of-work trưởng thành mà không làm gián đoạn tính toàn vẹn hoặc khả năng sử dụng của nó.

---

## 10. Tham số Mạng

PoCX xây dựng trên cơ sở hạ tầng mạng Bitcoin và tái sử dụng framework tham số chuỗi. Để hỗ trợ đào dựa trên dung lượng, khoảng khối, xử lý ủy quyền và mở rộng plot, nhiều tham số đã được mở rộng hoặc ghi đè. Điều này bao gồm mục tiêu thời gian khối, trợ cấp ban đầu, lịch trình halving, độ trễ kích hoạt và thu hồi ủy quyền, cũng như định danh mạng như magic byte, cổng và tiền tố Bech32. Môi trường testnet và regtest tiếp tục điều chỉnh các tham số này để cho phép lặp nhanh và testing dung lượng thấp.

Các bảng dưới đây tóm tắt các cài đặt mainnet, testnet và regtest kết quả, nêu bật cách PoCX điều chỉnh các tham số cốt lõi của Bitcoin cho mô hình đồng thuận dựa trên lưu trữ.

### 10.1 Mainnet

| Tham số | Giá trị |
|---------|--------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Cổng mặc định | 8888 |
| Bech32 HRP | `pocx` |
| Mục tiêu thời gian khối | 120 giây |
| Trợ cấp ban đầu | 10 BTC |
| Khoảng halving | 1050000 khối (~4 năm) |
| Tổng cung | ~21 triệu BTC |
| Kích hoạt ủy quyền | 30 khối |
| Thu hồi ủy quyền | 720 khối |
| Cửa sổ cuộn | 24 khối |

### 10.2 Testnet

| Tham số | Giá trị |
|---------|--------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Cổng mặc định | 18888 |
| Bech32 HRP | `tpocx` |
| Mục tiêu thời gian khối | 120 giây |
| Tham số khác | Giống mainnet |

### 10.3 Regtest

| Tham số | Giá trị |
|---------|--------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Cổng mặc định | 18444 |
| Bech32 HRP | `rpocx` |
| Mục tiêu thời gian khối | 1 giây |
| Khoảng halving | 500 khối |
| Kích hoạt ủy quyền | 4 khối |
| Thu hồi ủy quyền | 8 khối |
| Chế độ dung lượng thấp | Bật (~4 MB plot) |

---

## 11. Công trình Liên quan

Qua nhiều năm, một số dự án blockchain và đồng thuận đã khám phá mô hình đào dựa trên lưu trữ hoặc lai. PoCX xây dựng trên dòng dõi này đồng thời giới thiệu cải tiến về bảo mật, hiệu quả và tương thích.

**Burstcoin / Signum.** Burstcoin giới thiệu hệ thống Proof-of-Capacity (PoC) thực tế đầu tiên năm 2014, định nghĩa các khái niệm cốt lõi như plot, nonce, scoop và đào dựa trên deadline. Các kế thừa của nó, đáng chú ý là Signum (trước đây Burstcoin), mở rộng hệ sinh thái và cuối cùng phát triển thành cái được gọi là Proof-of-Commitment (PoC+), kết hợp cam kết lưu trữ với staking tùy chọn để ảnh hưởng đến dung lượng hiệu quả. PoCX kế thừa nền tảng đào dựa trên lưu trữ từ các dự án này, nhưng khác biệt đáng kể thông qua định dạng plot được gia cố (mã hóa XOR-transpose), mở rộng công việc plot động, làm mượt deadline ("Time Bending") và hệ thống ủy quyền linh hoạt - tất cả trong khi neo trong codebase Bitcoin Core thay vì duy trì fork mạng độc lập.

**Chia.** Chia triển khai Proof of Space and Time, kết hợp bằng chứng lưu trữ dựa trên đĩa với thành phần thời gian được thực thi qua Verifiable Delay Function (VDF). Thiết kế của nó giải quyết một số lo ngại về tái sử dụng bằng chứng và tạo thách thức mới, khác biệt với PoC cổ điển. PoCX không áp dụng mô hình bằng chứng neo thời gian đó; thay vào đó, nó duy trì đồng thuận dựa trên lưu trữ với khoảng dự đoán được, tối ưu hóa cho tương thích dài hạn với kinh tế UTXO và công cụ có nguồn gốc Bitcoin.

**Spacemesh.** Spacemesh đề xuất lược đồ Proof-of-Space-Time (PoST) sử dụng topo mạng dựa trên DAG (mesh). Trong mô hình này, người tham gia phải định kỳ chứng minh lưu trữ được phân bổ vẫn nguyên vẹn theo thời gian, thay vì dựa vào một tập dữ liệu được tính toán trước đơn lẻ. PoCX, ngược lại, xác minh cam kết lưu trữ tại thời gian khối chỉ - với định dạng plot được gia cố và xác thực bằng chứng nghiêm ngặt - tránh overhead của bằng chứng lưu trữ liên tục đồng thời bảo toàn hiệu quả và phi tập trung hóa.

---

## 12. Kết luận

Bitcoin-PoCX chứng minh rằng đồng thuận tiết kiệm năng lượng có thể được tích hợp vào Bitcoin Core đồng thời bảo toàn các thuộc tính bảo mật và mô hình kinh tế. Các đóng góp chính bao gồm mã hóa XOR-transpose (buộc kẻ tấn công tính 4096 nonce cho mỗi tra cứu, loại bỏ tấn công nén), thuật toán Time Bending (biến đổi phân phối giảm variance thời gian khối), hệ thống ủy quyền forging (ủy thác dựa trên OP_RETURN cho phép đào pool không giám sát), mở rộng động (phù hợp với halving để duy trì biên độ bảo mật) và tích hợp tối thiểu (mã được đánh dấu tính năng cô lập trong thư mục chuyên dụng).

Hệ thống hiện đang trong giai đoạn testnet. Năng lực đào được suy ra từ dung lượng lưu trữ thay vì hash rate, giảm tiêu thụ năng lượng theo bậc độ lớn đồng thời duy trì mô hình kinh tế đã được chứng minh của Bitcoin.

---

## Tài liệu Tham khảo

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Giấy phép**: MIT
**Tổ chức**: Proof of Capacity Consortium
**Trạng thái**: Giai đoạn Testnet
