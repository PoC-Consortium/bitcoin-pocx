# Bitcoin-PoCX: Mahusay sa Enerhiyang Consensus para sa Bitcoin Core

**Bersyon**: 2.0 Draft
**Petsa**: Disyembre 2025
**Organisasyon**: Proof of Capacity Consortium

---

## Abstrakto

Ang Proof-of-Work (PoW) consensus ng Bitcoin ay nagbibigay ng matibay na seguridad ngunit kumukonsumo ng malaking enerhiya dahil sa tuloy-tuloy na real-time hash computation. Ipiniprisinta namin ang Bitcoin-PoCX, isang Bitcoin fork na pumapalit sa PoW ng Proof of Capacity (PoC), kung saan ang mga miner ay nag-precompute at nag-iimbak ng malalaking hanay ng disk-stored hash sa panahon ng plotting at kasunod na nagmimina sa pamamagitan ng paggawa ng magagaang lookup sa halip na patuloy na pag-hash. Sa pamamagitan ng paglipat ng computation mula sa yugto ng mining patungo sa isang beses na yugto ng plotting, lubos na binabawasan ng Bitcoin-PoCX ang pagkonsumo ng enerhiya habang pinapagana ang mining sa commodity hardware, pinapababa ang hadlang sa pakikilahok at pinipigilan ang mga pressure ng sentralisasyon na likas sa ASIC-dominated PoW, habang pinapanatili ang mga security assumption at economic behavior ng Bitcoin.

Ang aming implementasyon ay nagpapakilala ng ilang pangunahing inobasyon:
(1) Isang hardened plot format na nag-aalis ng lahat ng kilalang time-memory-tradeoff attack sa mga kasalukuyang sistema ng PoC, na tinitiyak na ang epektibong kapangyarihan sa mining ay nananatiling mahigpit na proporsyonal sa committed storage capacity;
(2) Ang Time-Bending algorithm, na nagbabago ng mga deadline distribution mula exponential patungong chi-squared, na binabawasan ang variance ng block-time nang hindi binabago ang mean;
(3) Isang OP_RETURN-based na mekanismo ng forging-assignment na nagpapagana ng non-custodial pool mining; at
(4) Dynamic compression scaling, na nagpapataas ng difficulty ng plot-generation na naka-align sa mga iskedyul ng halving upang mapanatili ang mga long-term security margin habang umuunlad ang hardware.

Pinapanatili ng Bitcoin-PoCX ang arkitektura ng Bitcoin Core sa pamamagitan ng minimal, feature-flagged na mga modipikasyon, na naghihiwalay sa PoC logic mula sa kasalukuyang consensus code. Pinapanatili ng sistema ang monetary policy ng Bitcoin sa pamamagitan ng pag-target ng 120-segundong block interval at pag-adjust ng block subsidy sa 10 BTC. Ang nabawasang subsidy ay nag-o-offset sa limang beses na pagtaas ng block frequency, pinapanatili ang long-term issuance rate na naka-align sa orihinal na iskedyul ng Bitcoin at pinapanatili ang ~21 milyong maximum supply.

---

## 1. Panimula

### 1.1 Motibasyon

Ang Proof-of-Work (PoW) consensus ng Bitcoin ay napatunayang secure sa loob ng higit isang dekada, ngunit sa makabuluhang halaga: ang mga miner ay dapat patuloy na gumastos ng mga computational resource, na nagreresulta sa mataas na pagkonsumo ng enerhiya. Higit pa sa mga alalahanin sa kahusayan, may mas malawak na motibasyon: paggalugad ng mga alternatibong mekanismo ng consensus na pinapanatili ang seguridad habang pinapababa ang hadlang sa pakikilahok. Pinapagana ng PoC ang halos sinuman na may commodity storage hardware na mag-mine nang epektibo, binabawasan ang mga pressure ng sentralisasyon na nakikita sa ASIC-dominated PoW mining.

Nakakamit ng Proof of Capacity (PoC) ito sa pamamagitan ng pagkuha ng kapangyarihan sa mining mula sa storage commitment sa halip na patuloy na computation. Ang mga miner ay nag-precompute ng malalaking hanay ng disk-stored hash—mga plot—sa isang beses na yugto ng plotting. Ang mining ay binubuo ng magagaang lookup, lubos na binabawasan ang paggamit ng enerhiya habang pinapanatili ang mga security assumption ng resource-based consensus.

### 1.2 Integrasyon sa Bitcoin Core

Ini-integrate ng Bitcoin-PoCX ang PoC consensus sa Bitcoin Core sa halip na gumawa ng bagong blockchain. Ginagamit ng approach na ito ang napatunayang seguridad ng Bitcoin Core, mature na networking stack, at malawakang na-adopt na mga tool, habang pinapanatiling minimal at feature-flagged ang mga modipikasyon. Ang PoC logic ay nakahiwalay mula sa kasalukuyang consensus code, tinitiyak na ang pangunahing functionality—block validation, mga operasyon ng wallet, mga format ng transaksyon—ay nananatiling halos hindi nagbabago.

### 1.3 Mga Layunin ng Disenyo

**Seguridad**: Panatilihin ang katibayan na katumbas ng Bitcoin; ang mga atake ay nangangailangan ng karamihan ng storage capacity.

**Kahusayan**: Bawasan ang patuloy na computational load sa mga antas ng disk I/O.

**Accessibility**: Paganahin ang mining gamit ang commodity hardware, pinapababa ang mga hadlang sa pagpasok.

**Minimal na Integrasyon**: Ipakilala ang PoC consensus na may minimal na modification footprint.

---

## 2. Background: Proof of Capacity

### 2.1 Kasaysayan

Ang Proof of Capacity (PoC) ay ipinakilala ng Burstcoin noong 2014 bilang isang energy-efficient na alternatibo sa Proof-of-Work (PoW). Ipinakita ng Burstcoin na ang kapangyarihan sa mining ay maaaring makuha mula sa committed storage sa halip na tuloy-tuloy na real-time hashing: ang mga miner ay nag-precompute ng malalaking dataset ("mga plot") nang isang beses at pagkatapos ay nagmina sa pamamagitan ng pagbabasa ng maliliit, nakapirming bahagi ng mga ito.

Pinatunayan ng mga maagang implementasyon ng PoC na viable ang konsepto ngunit ipinahayag din na ang plot format at cryptographic structure ay kritikal para sa seguridad. Maraming time-memory tradeoff ang nagpahintulot sa mga attacker na mag-mine nang epektibo na may mas kaunting storage kaysa sa mga matapat na kalahok. Ipinahayag nito na ang seguridad ng PoC ay nakasalalay sa plot design—hindi lamang sa paggamit ng storage bilang isang resource.

Ang legacy ng Burstcoin ay nag-establish ng PoC bilang isang praktikal na mekanismo ng consensus at nagbigay ng pundasyon kung saan bumubuo ang PoCX.

### 2.2 Mga Pangunahing Konsepto

Ang PoC mining ay batay sa malalaki, precomputed na plot file na naka-store sa disk. Ang mga plot na ito ay naglalaman ng "frozen computation": ang mamahaling hashing ay ginagawa nang isang beses sa panahon ng plotting, at ang mining ay binubuo ng magagaang disk read at simpleng verification. Kasama sa mga pangunahing elemento ang:

**Nonce:**
Ang pangunahing yunit ng plot data. Ang bawat nonce ay naglalaman ng 4096 scoop (256 KiB sa kabuuan) na ginawa sa pamamagitan ng Shabal256 mula sa address ng miner at nonce index.

**Scoop:**
Isang 64-byte na segment sa loob ng isang nonce. Para sa bawat block, deterministically na pinipili ng network ang isang scoop index (0-4095) batay sa generation signature ng nakaraang block. Tanging ang scoop na ito bawat nonce ang kailangang basahin.

**Generation Signature:**
Isang 256-bit na halaga na nakuha mula sa nakaraang block. Nagbibigay ito ng entropy para sa scoop selection at pumipigil sa mga miner na mahulaan ang mga hinaharap na scoop index.

**Warp:**
Isang structural group ng 4096 nonce (1 GiB). Ang mga warp ang kaugnay na yunit para sa mga compression-resistant plot format.

### 2.3 Proseso ng Mining at Quality Pipeline

Ang PoC mining ay binubuo ng isang beses na plotting step at isang magaang per-block routine:

**Isang Beses na Setup:**
- Plot generation: Kalkulahin ang mga nonce sa pamamagitan ng Shabal256 at isulat ang mga ito sa disk.

**Per-Block Mining:**
- Scoop selection: Tukuyin ang scoop index mula sa generation signature.
- Plot scanning: Basahin ang scoop na iyon mula sa lahat ng nonce sa mga plot ng miner.

**Quality Pipeline:**
- Raw quality: I-hash ang bawat scoop kasama ang generation signature gamit ang Shabal256Lite upang makakuha ng 64-bit quality value (mas mababa ay mas mabuti).
- Deadline: I-convert ang quality sa isang deadline gamit ang base target (isang difficulty-adjusted parameter na tinitiyak na maabot ng network ang target na block interval): `deadline = quality / base_target`
- Bended deadline: Ilapat ang Time-Bending transformation upang mabawasan ang variance habang pinapanatili ang inaasahang block time.

**Block Forging:**
Ang miner na may pinakamaikling (bended) deadline ay nag-forge ng susunod na block kapag lumipas na ang oras na iyon.

Hindi tulad ng PoW, halos lahat ng computation ay nangyayari sa panahon ng plotting; ang aktibong mining ay pangunahing disk-bound at napakababang power.

### 2.4 Mga Kilalang Vulnerability sa Mga Nakaraang Sistema

**POC1 Distribution Flaw:**
Ang orihinal na Burstcoin POC1 format ay nagpakita ng structural bias: ang mga low-index scoop ay makabuluhang mas mura na i-recompute on-the-fly kaysa sa mga high-index scoop. Nagpakilala ito ng isang non-uniform time-memory tradeoff, na nagpapahintulot sa mga attacker na bawasan ang kinakailangang storage para sa mga scoop na iyon at sinisira ang palagay na lahat ng precomputed data ay pantay na mahal.

**XOR Compression Attack (POC2):**
Sa POC2, maaaring kumuha ang isang attacker ng anumang hanay ng 8192 nonce at hatiin ang mga ito sa dalawang block ng 4096 nonce (A at B). Sa halip na i-store ang parehong block, ini-store ng attacker ang isang derived structure lamang: `A XOR transpose(B)`, kung saan ang transpose ay nagpapalit ng scoop at nonce index—ang scoop S ng nonce N sa block B ay nagiging scoop N ng nonce S.

Sa panahon ng mining, kapag kailangan ang scoop S ng nonce N, nire-reconstruct ito ng attacker sa pamamagitan ng:
1. Pagbabasa ng stored XOR value sa posisyon (S, N)
2. Pag-compute ng nonce N mula sa block A upang makuha ang scoop S
3. Pag-compute ng nonce S mula sa block B upang makuha ang transposed scoop N
4. Pag-XOR ng lahat ng tatlong halaga upang mabawi ang orihinal na 64-byte scoop

Binabawasan nito ang storage ng 50%, habang nangangailangan lamang ng dalawang nonce computation bawat lookup—isang halaga na malayong mas mababa sa threshold na kailangan upang ipatupad ang buong precomputation. Viable ang atake dahil ang pag-compute ng isang row (isang nonce, 4096 scoop) ay mura, samantalang ang pag-compute ng isang column (isang scoop sa 4096 nonce) ay mangangailangan ng pag-regenerate ng lahat ng nonce. Inilalantad ng transpose structure ang imbalansyang ito.

Ipinakita nito ang pangangailangan para sa isang plot format na pumipigil sa ganitong structured recombination at inaalis ang underlying time-memory tradeoff. Inilalarawan ng Seksyon 3.3 kung paano tinutugunan at niresolba ng PoCX ang kahinaang ito.

### 2.5 Transisyon sa PoCX

Ang mga limitasyon ng mga nakaraang sistema ng PoC ay nagpalinaw na ang secure, patas, at decentralized na storage mining ay nakadepende sa maingat na engineered na mga plot structure. Tinutugunan ng Bitcoin-PoCX ang mga isyung ito gamit ang isang hardened plot format, pinahusay na deadline distribution, at mga mekanismo para sa decentralized pool mining—na inilalarawan sa susunod na seksyon.

---

## 3. PoCX Plot Format

### 3.1 Base Nonce Construction

Ang isang nonce ay isang 256 KiB data structure na deterministically na nakuha mula sa tatlong parameter: isang 20-byte address payload, isang 32-byte seed, at isang 64-bit nonce index.

Ang construction ay nagsisimula sa pamamagitan ng pagsasama-sama ng mga input na ito at pag-hash sa mga ito gamit ang Shabal256 upang makabuo ng isang initial hash. Ang hash na ito ang nagsisilbing panimulang punto para sa isang iterative expansion process: paulit-ulit na inilalapat ang Shabal256, kung saan ang bawat hakbang ay nakadepende sa dating nabuong data, hanggang mapunan ang buong 256 KiB buffer. Ang chained process na ito ang kumakatawan sa computational work na ginagawa sa panahon ng plotting.

Ang isang final diffusion step ay nagha-hash ng completed buffer at nagba-XOR ng resulta sa lahat ng byte. Tinitiyak nito na ang buong buffer ay nakalkulado at ang mga miner ay hindi maaaring mag-shortcut ng kalkulasyon. Ang PoC2 shuffle ay pagkatapos ay inilalapat, na nagpapalit ng lower at upper halves ng bawat scoop upang garantiyahin na ang lahat ng scoop ay nangangailangan ng katumbas na computational effort.

Ang final nonce ay binubuo ng 4096 scoop na tig-64 byte bawat isa at bumubuo ng pangunahing yunit na ginagamit sa mining.

### 3.2 SIMD-Aligned Plot Layout

Upang i-maximize ang throughput sa modernong hardware, inaayos ng PoCX ang nonce data sa disk upang mapadali ang vectorized processing. Sa halip na i-store ang bawat nonce nang sequential, inaayos ng PoCX ang kaukulang 4-byte word sa maraming consecutive nonce nang magkakadikit. Pinapayagan nito ang isang memory fetch na magbigay ng data para sa lahat ng SIMD lane, pinapaliit ang mga cache miss at inaalis ang scatter-gather overhead.

```
Tradisyunal na layout:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD layout:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Ang layout na ito ay nakikinabang sa parehong CPU at GPU miner, na nagpapagana ng high-throughput, parallelized scoop evaluation habang pinapanatili ang isang simpleng scalar access pattern para sa consensus verification. Tinitiyak nito na ang mining ay nililimitahan ng storage bandwidth sa halip na CPU computation, pinapanatili ang low-power na katangian ng Proof of Capacity.

### 3.3 Warp Structure at XOR-Transpose Encoding

Ang isang warp ay ang pangunahing storage unit sa PoCX, na binubuo ng 4096 nonce (1 GiB). Ang uncompressed format, na tinutukoy bilang X0, ay naglalaman ng mga base nonce eksakto tulad ng ginawa ng construction sa Seksyon 3.1.

**XOR-Transpose Encoding (X1)**

Upang alisin ang mga structural time-memory tradeoff na umiiral sa mga nakaraang sistema ng PoC, kinukuha ng PoCX ang isang hardened mining format, X1, sa pamamagitan ng pag-apply ng XOR-transpose encoding sa mga pares ng X0 warp.

Upang buuin ang scoop S ng nonce N sa isang X1 warp:

1. Kunin ang scoop S ng nonce N mula sa unang X0 warp (direktang posisyon)
2. Kunin ang scoop N ng nonce S mula sa pangalawang X0 warp (transposed na posisyon)
3. I-XOR ang dalawang 64-byte na halaga upang makuha ang X1 scoop

Ang transpose step ay nagpapalit ng mga scoop at nonce index. Sa mga termino ng matrix—kung saan ang mga row ay kumakatawan sa mga scoop at ang mga column ay kumakatawan sa mga nonce—pinagsasama nito ang elemento sa posisyon (S, N) sa unang warp kasama ang elemento sa (N, S) sa pangalawa.

**Bakit Nito Inaalis ang Compression Attack Surface**

Ang XOR-transpose ay nag-i-interlock ng bawat scoop sa isang buong row at isang buong column ng underlying X0 data. Ang pag-recover ng isang solong X1 scoop ay samakatuwid nangangailangan ng access sa data na sumasaklaw sa lahat ng 4096 scoop index. Anumang pagtatangkang kalkulahin ang nawawalang data ay mangangailangan ng pag-regenerate ng 4096 buong nonce, sa halip na isang solong nonce—inaalis ang asymmetric cost structure na sinamantala ng XOR attack para sa POC2 (Seksyon 2.4).

Bilang resulta, ang pag-iimbak ng buong X1 warp ang nagiging tanging computationally viable na estratehiya para sa mga miner, sinasara ang time-memory tradeoff na sinamantala sa mga nakaraang disenyo.

### 3.4 Disk Layout

Ang mga PoCX plot file ay binubuo ng maraming consecutive X1 warp. Upang i-maximize ang operational efficiency sa panahon ng mining, ang data sa loob ng bawat file ay nakaayos ayon sa scoop: lahat ng scoop 0 data mula sa bawat warp ay naka-store nang sequential, sinusundan ng lahat ng scoop 1 data, at iba pa, hanggang scoop 4095.

Ang **scoop-sequential ordering** na ito ay nagpapahintulot sa mga miner na basahin ang kumpletong data na kinakailangan para sa isang piniling scoop sa isang sequential disk access, pinapaliit ang mga seek time at nima-maximize ang throughput sa mga commodity storage device.

Pinagsama sa XOR-transpose encoding ng Seksyon 3.3, tinitiyak ng layout na ito na ang file ay parehong **structurally hardened** at **operationally efficient**: sinusuportahan ng sequential scoop ordering ang optimal disk I/O, habang pinapayagan ng SIMD-aligned memory layout (tingnan ang Seksyon 3.2) ang high-throughput, parallelized scoop evaluation.

### 3.5 Proof-of-Work Scaling (Xn)

Nagpapatupad ang PoCX ng scalable precomputation sa pamamagitan ng konsepto ng mga scaling level, na tinukoy bilang Xn, upang umakma sa umuusbong na performance ng hardware. Ang baseline X1 format ay kumakatawan sa unang XOR-transpose hardened warp structure.

Ang bawat scaling level Xn ay nagpapataas ng proof-of-work na naka-embed sa bawat warp nang exponentially kumpara sa X1: ang work na kinakailangan sa level Xn ay 2^(n-1) na beses kaysa sa X1. Ang paglipat mula Xn patungong Xn+1 ay operationally katumbas ng pag-apply ng XOR sa mga pares ng magkatabing warp, incrementally na nag-e-embed ng mas maraming proof-of-work nang hindi binabago ang underlying plot size.

Ang mga kasalukuyang plot file na ginawa sa mas mababang scaling level ay maaari pa ring gamitin para sa mining, ngunit nag-co-contribute sila ng proporsyonal na mas kaunting work patungo sa block generation, na sumasalamin sa kanilang mas mababang embedded proof-of-work. Tinitiyak ng mekanismong ito na ang mga PoCX plot ay nananatiling secure, flexible, at economically balanced sa paglipas ng panahon.

### 3.6 Seed Functionality

Ang seed parameter ay nagpapagana ng maraming non-overlapping plot bawat address nang walang manual coordination.

**Problema (POC2)**: Kailangang manual na subaybayan ng mga miner ang mga nonce range sa mga plot file upang maiwasan ang overlap. Ang mga overlapping nonce ay nag-aaksaya ng storage nang hindi nagpapataas ng kapangyarihan sa mining.

**Solusyon**: Ang bawat `(address, seed)` pair ay nagde-define ng isang independent keyspace. Ang mga plot na may iba't ibang seed ay hindi kailanman nag-o-overlap, anuman ang nonce range. Malayang makakagawa ang mga miner ng mga plot nang walang coordination.

---

## 4. Proof of Capacity Consensus

Pinapalawak ng PoCX ang Nakamoto consensus ng Bitcoin gamit ang isang storage-bound proof mechanism. Sa halip na gumastos ng enerhiya sa paulit-ulit na hashing, ang mga miner ay nag-commit ng malalaking halaga ng precomputed data—mga plot—sa disk. Sa panahon ng block generation, kailangan nilang hanapin ang isang maliit, hindi mahuhulaan na bahagi ng data na ito at baguhin ito sa isang proof. Ang miner na nagbibigay ng pinakamahusay na proof sa loob ng inaasahang time window ay nakakuha ng karapatang mag-forge ng susunod na block.

Inilalarawan ng kabanatang ito kung paano isinasaayos ng PoCX ang block metadata, kinukuha ang hindi mahuhulaan, at binabago ang static storage sa isang secure, low-variance consensus mechanism.

### 4.1 Istruktura ng Block

Pinapanatili ng PoCX ang pamilyar na Bitcoin-style block header ngunit nagpapakilala ng karagdagang mga consensus field na kinakailangan para sa capacity-based mining. Ang mga field na ito ay sama-samang nagbubuklod sa block sa stored plot ng miner, sa difficulty ng network, at sa cryptographic entropy na nagde-define ng bawat mining challenge.

Sa mataas na antas, ang isang PoCX block ay naglalaman ng: ang block height, na tahasang naka-record upang pasimplehin ang contextual validation; ang generation signature, isang pinagmulan ng bagong entropy na nag-uugnay sa bawat block sa nauna nito; ang base target, na kumakatawan sa network difficulty sa inverse form (mas mataas na halaga ay tumutugma sa mas madaling mining); ang PoCX proof, na nagpapakilala sa plot ng miner, ang compression level na ginamit sa panahon ng plotting, ang napiling nonce, at ang quality na nakuha mula rito; at isang signing key at signature, na nagpapatunay ng kontrol sa kapasidad na ginamit upang i-forge ang block (o ng isang assigned forging key).

Ang proof ay nag-e-embed ng lahat ng consensus-relevant na impormasyon na kailangan ng mga validator upang i-recompute ang challenge, i-verify ang napiling scoop, at kumpirmahin ang resultang quality. Sa pamamagitan ng pagpapalawak sa halip na muling pagdidisenyo ng block structure, nananatiling conceptually aligned ang PoCX sa Bitcoin habang pinapagana ang isang pundamentally iba na pinagmulan ng mining work.

### 4.2 Generation Signature Chain

Ang generation signature ay nagbibigay ng hindi mahuhulaan na kinakailangan para sa secure na Proof of Capacity mining. Ang bawat block ay kinukuha ang generation signature nito mula sa signature at signer ng nakaraang block, tinitiyak na ang mga miner ay hindi maaaring mahulaan ang mga hinaharap na challenge o mag-precompute ng mga advantageous plot region:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Gumagawa ito ng isang sequence ng cryptographically strong, miner-dependent entropy value. Dahil ang public key ng isang miner ay hindi kilala hanggang ma-publish ang nakaraang block, walang kalahok ang makapaghuhula ng mga hinaharap na scoop selection. Pinipigilan nito ang selective precomputation o strategic plotting at tinitiyak na ang bawat block ay nagpapakilala ng tunay na bagong mining work.

### 4.3 Proseso ng Forging

Ang mining sa PoCX ay binubuo ng pagbabago ng stored data sa isang proof na ganap na pinapagalaw ng generation signature. Bagama't ang proseso ay deterministic, ang hindi mahuhulaan ng signature ay tinitiyak na ang mga miner ay hindi maaaring maghanda nang maaga at dapat paulit-ulit na i-access ang kanilang stored plot.

**Challenge Derivation (Scoop Selection):** Hina-hash ng miner ang kasalukuyang generation signature kasama ang block height upang makakuha ng scoop index sa range 0-4095. Tinutukoy ng index na ito kung aling 64-byte segment ng bawat stored nonce ang lalahok sa proof. Dahil ang generation signature ay nakadepende sa signer ng nakaraang block, ang scoop selection ay nagiging kilala lamang sa sandaling ma-publish ang block.

**Proof Evaluation (Quality Calculation):** Para sa bawat nonce sa isang plot, kinukuha ng miner ang napiling scoop at hina-hash ito kasama ang generation signature upang makakuha ng quality—isang 64-bit na halaga na ang magnitude ay tumutukoy sa competitiveness ng miner. Ang mas mababang quality ay tumutugma sa isang mas mahusay na proof.

**Deadline Formation (Time Bending):** Ang raw deadline ay proporsyonal sa quality at inversely proportional sa base target. Sa mga legacy PoC design, ang mga deadline na ito ay sumusunod sa isang highly skewed exponential distribution, na gumagawa ng mahabang tail delay na hindi nagbibigay ng karagdagang seguridad. Binabago ng PoCX ang raw deadline gamit ang Time Bending (Seksyon 4.4), binabawasan ang variance at tinitiyak ang predictable block interval. Kapag lumipas na ang bended deadline, nag-forge ang miner ng block sa pamamagitan ng pag-embed ng proof at pag-sign nito gamit ang effective forging key.

### 4.4 Time Bending

Ang Proof of Capacity ay gumagawa ng exponentially distributed deadline. Pagkatapos ng maikling panahon—karaniwang ilang dosenang segundo—nakilala na ng bawat miner ang kanilang pinakamahusay na proof, at anumang karagdagang oras ng paghihintay ay nag-co-contribute lamang ng latency, hindi seguridad.

Binabago ng Time Bending ang distribution sa pamamagitan ng pag-apply ng cube root transformation:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Pinapanatili ng scale factor ang inaasahang block time (120 segundo) habang lubos na binabawasan ang variance. Ang mga maikling deadline ay pinapalawak, pinapabuti ang block propagation at network safety. Ang mga mahabang deadline ay nako-compress, pinipigilan ang mga outlier na mag-delay ng chain.

![Block Time Distributions](blocktime_distributions.svg)

Pinapanatili ng Time Bending ang informational content ng underlying proof. Hindi nito binabago ang competitiveness sa mga miner; nire-reallocate lamang nito ang oras ng paghihintay upang makagawa ng mas makinis, mas predictable block interval. Gumagamit ang implementasyon ng fixed-point arithmetic (Q42 format) at 256-bit integer upang matiyak ang deterministic na mga resulta sa lahat ng platform.

### 4.5 Difficulty Adjustment

Nire-regulate ng PoCX ang block production gamit ang base target, isang inverse difficulty measure. Ang inaasahang block time ay proporsyonal sa ratio na `quality / base_target`, kaya ang pagpapataas ng base target ay nagpapabilis ng block creation habang ang pagpapababa nito ay nagpapabagal ng chain.

Nag-aadjust ang difficulty bawat block gamit ang nasukat na oras sa pagitan ng mga kamakailang block kumpara sa target interval. Ang madalas na adjustment na ito ay kinakailangan dahil ang storage capacity ay maaaring idagdag o alisin nang mabilis—hindi tulad ng hashpower ng Bitcoin, na nagbabago nang mas mabagal.

Sumusunod ang adjustment sa dalawang gumagabay na constraint: **Graduality**—ang mga per-block change ay bounded (±20% maximum) upang maiwasan ang mga oscillation o manipulation; **Hardening**—ang base target ay hindi maaaring lumampas sa genesis value nito, pinipigilan ang network na kailanman ibaba ang difficulty sa ibaba ng orihinal na security assumption.

### 4.6 Block Validity

Ang isang block sa PoCX ay valid kapag nagpapakita ito ng isang verifiable storage-derived proof na consistent sa consensus state. Independiyenteng kini-recompute ng mga validator ang scoop selection, kinukuha ang inaasahang quality mula sa isinumiteng nonce at plot metadata, inilalapat ang Time Bending transformation, at kinukumpirma na ang miner ay eligible na mag-forge ng block sa idineklara oras.

Partikular, ang isang valid na block ay nangangailangan ng: lumipas na ang deadline mula sa parent block; ang isinumiteng quality ay tumutugma sa computed quality para sa proof; ang scaling level ay natutugunan ang network minimum; ang generation signature ay tumutugma sa inaasahang halaga; ang base target ay tumutugma sa inaasahang halaga; ang block signature ay nagmumula sa effective signer; at ang coinbase ay nagbabayad sa address ng effective signer.

---

## 5. Mga Forging Assignment

### 5.1 Motibasyon

Pinapayagan ng mga forging assignment ang mga may-ari ng plot na magdelega ng block-forging authority nang hindi kailanman isinusuko ang pagmamay-ari ng kanilang mga plot. Pinapagana ng mekanismong ito ang pool mining at mga cold-storage setup habang pinapanatili ang mga security guarantee ng PoCX.

Sa pool mining, maaaring mag-authorize ang mga may-ari ng plot ng pool na mag-forge ng mga block sa kanilang ngalan. Ang pool ay nag-a-assemble ng mga block at namamahagi ng mga reward, ngunit hindi ito nakakakuha ng custody sa mga plot mismo. Ang delegation ay reversible anumang oras, at ang mga may-ari ng plot ay nananatiling malaya na umalis sa pool o baguhin ang mga configuration nang hindi kailangang mag-replot.

Sinusuportahan din ng mga assignment ang malinis na paghihiwalay sa pagitan ng mga cold at hot key. Ang private key na kumokontrol sa plot ay maaaring manatiling offline, habang ang isang hiwalay na forging key—naka-store sa isang online machine—ang gumagawa ng mga block. Ang isang compromise ng forging key ay samakatuwid nakokompromiso lamang ang forging authority, hindi ang pagmamay-ari. Ang plot ay nananatiling ligtas at ang assignment ay maaaring ma-revoke, agad na sinasara ang security gap.

Samakatuwid, ang mga forging assignment ay nagbibigay ng operational flexibility habang pinapanatili ang prinsipyo na ang kontrol sa stored capacity ay hindi dapat kailanman ma-transfer sa mga intermediary.

### 5.2 Assignment Protocol

Ang mga assignment ay idinedeklara sa pamamagitan ng mga OP_RETURN transaction upang maiwasan ang hindi kinakailangang paglaki ng UTXO set. Ang isang assignment transaction ay tumutukoy ng plot address at ng forging address na awtorisadong mag-produce ng mga block gamit ang kapasidad ng plot na iyon. Ang isang revocation transaction ay naglalaman lamang ng plot address. Sa parehong kaso, pinapatunayan ng may-ari ng plot ang kontrol sa pamamagitan ng pag-sign ng spending input ng transaksyon.

Ang bawat assignment ay dumadaan sa isang sequence ng maayos na na-define na mga state (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Pagkatapos makumpirma ang isang assignment transaction, papasok ang sistema sa isang maikling activation phase. Ang delay na ito—30 block, humigit-kumulang isang oras—ay tinitiyak ang katatagan sa panahon ng mga block race at pinipigilan ang adversarial rapid switching ng mga forging identity. Kapag nag-expire ang activation period na ito, ang assignment ay nagiging aktibo at nananatiling gayon hanggang mag-issue ang may-ari ng plot ng revocation.

Ang mga revocation ay nagti-transition sa isang mas mahabang delay period na 720 block, humigit-kumulang isang araw. Sa panahong ito, ang nakaraang forging address ay nananatiling aktibo. Ang mas mahabang delay na ito ay nagbibigay ng operational stability para sa mga pool, pinipigilan ang strategic "assignment hopping" at nagbibigay sa mga infrastructure provider ng sapat na katiyakan upang mag-operate nang mahusay. Pagkatapos mag-expire ang revocation delay, nakukumpleto ang revocation, at ang may-ari ng plot ay malayang mag-designate ng bagong forging key.

Ang assignment state ay pinapanatili sa isang consensus-layer structure na parallel sa UTXO set at sumusuporta sa undo data para sa ligtas na paghawak ng mga chain reorganization.

### 5.3 Mga Patakaran sa Validation

Para sa bawat block, tinutukoy ng mga validator ang effective signer—ang address na dapat lumagda sa block at tumanggap ng coinbase reward. Ang signer na ito ay nakadepende lamang sa assignment state sa height ng block.

Kung walang assignment o hindi pa nakukumpleto ng assignment ang activation phase nito, ang may-ari ng plot ang nananatiling effective signer. Kapag naging aktibo ang isang assignment, ang assigned forging address ang dapat lumagda. Sa panahon ng revocation, nagpapatuloy ang forging address na lumagda hanggang mag-expire ang revocation delay. Noon lamang bumabalik ang authority sa may-ari ng plot.

Ipinapatupad ng mga validator na ang block signature ay ginawa ng effective signer, na ang coinbase ay nagbabayad sa parehong address, at na ang lahat ng transition ay sumusunod sa mga prescribed activation at revocation delay. Tanging ang may-ari ng plot lamang ang maaaring gumawa o mag-revoke ng mga assignment; ang mga forging key ay hindi maaaring magbago o mag-extend ng kanilang sariling mga pahintulot.

Samakatuwid, ang mga forging assignment ay nagpapakilala ng flexible delegation nang walang pagpapakilala ng trust. Ang pagmamay-ari ng underlying capacity ay laging nananatiling cryptographically anchored sa may-ari ng plot, habang ang forging authority ay maaaring ma-delegate, ma-rotate, o ma-revoke ayon sa pag-evolve ng mga operational need.

---

## 6. Dynamic Scaling

Habang umuunlad ang hardware, ang halaga ng pag-compute ng mga plot ay bumababa kumpara sa pagbabasa ng precomputed work mula sa disk. Kung walang mga countermeasure, ang mga attacker ay maaaring mag-generate ng mga proof on-the-fly na mas mabilis kaysa sa mga miner na nagbabasa ng stored work, sinasaktan ang security model ng Proof of Capacity.

Upang mapanatili ang intended security margin, nagpapatupad ang PoCX ng isang scaling schedule: ang minimum required scaling level para sa mga plot ay tumataas sa paglipas ng panahon. Ang bawat scaling level Xn, tulad ng inilalarawan sa Seksyon 3.5, ay nag-e-embed ng exponentially mas maraming proof-of-work sa loob ng plot structure, tinitiyak na ang mga miner ay nagpapatuloy na mag-commit ng malaking storage resource kahit na maging mas mura ang computation.

Ang schedule ay naka-align sa mga economic incentive ng network, partikular sa mga block reward halving. Habang bumababa ang reward bawat block, unti-unting tumataas ang minimum level, pinapanatili ang balanse sa pagitan ng plotting effort at mining potential:

| Panahon | Taon | Halving | Min Scaling | Plot Work Multiplier |
|--------|-------|----------|-------------|---------------------|
| Epoch 0 | 0-4 | 0 | X1 | 2× baseline |
| Epoch 1 | 4-12 | 1-2 | X2 | 4× baseline |
| Epoch 2 | 12-28 | 3-6 | X3 | 8× baseline |
| Epoch 3 | 28-60 | 7-14 | X4 | 16× baseline |
| Epoch 4 | 60-124 | 15-30 | X5 | 32× baseline |
| Epoch 5 | 124+ | 31+ | X6 | 64× baseline |

Maaaring opsyonal na maghanda ang mga miner ng mga plot na lumampas sa kasalukuyang minimum ng isang level, na nagpapahintulot sa kanila na mag-plan ahead at maiwasan ang mga agarang upgrade kapag nag-transition ang network sa susunod na epoch. Ang opsyonal na hakbang na ito ay hindi nagbibigay ng karagdagang kalamangan sa mga termino ng block probability—pinapayagan lamang nito ang isang mas makinis na operational transition.

Ang mga block na naglalaman ng mga proof na mas mababa sa minimum scaling level para sa kanilang height ay itinuturing na invalid. Sinusuri ng mga validator ang idineklara na scaling level sa proof laban sa kasalukuyang network requirement sa panahon ng consensus validation, tinitiyak na ang lahat ng kalahok na miner ay natutugunan ang umuusbong na mga security expectation.

---

## 7. Arkitektura ng Mining

Hinahati ng PoCX ang mga consensus-critical operation mula sa mga resource-intensive task ng mining, pinapagana ang parehong seguridad at kahusayan. Pinapanatili ng node ang blockchain, vine-validate ang mga block, pinamamahalaan ang mempool, at inilalantad ang isang RPC interface. Hinahawakan ng mga external miner ang plot storage, scoop reading, quality calculation, at deadline management. Ang paghihiwalay na ito ay nagpapanatiling simple at auditable ang consensus logic habang pinapayagan ang mga miner na mag-optimize para sa disk throughput.

### 7.1 Mining RPC Interface

Nakikipag-ugnayan ang mga miner sa node sa pamamagitan ng minimal na hanay ng mga RPC call. Ang get_mining_info RPC ay nagbibigay ng kasalukuyang block height, generation signature, base target, target deadline, at ang acceptable range ng mga plot scaling level. Gamit ang impormasyong ito, nag-compute ang mga miner ng mga candidate nonce. Pinapayagan ng submit_nonce RPC ang mga miner na magsumite ng iminumungkahing solusyon, kabilang ang plot identifier, nonce index, scaling level, at miner account. Sine-evaluate ng node ang submission at tumutugon gamit ang computed deadline kung valid ang proof.

### 7.2 Forging Scheduler

Pinapanatili ng node ang isang forging scheduler, na sumusubaybay sa mga incoming submission at napapanatili lamang ang pinakamahusay na solusyon para sa bawat block height. Ang mga isinumiteng nonce ay kinuqueue na may mga built-in na proteksyon laban sa submission flooding o denial-of-service attack. Naghihintay ang scheduler hanggang mag-expire ang calculated deadline o dumating ang isang mas mahusay na solusyon, kung saan ina-assemble nito ang isang block, nilalagdaan ito gamit ang effective forging key, at ipina-publish ito sa network.

### 7.3 Defensive Forging

Upang maiwasan ang mga timing attack o mga insentibo para sa clock manipulation, nagpapatupad ang PoCX ng defensive forging. Kung dumating ang isang nakikipagkumpitensyang block para sa parehong height, inihahambing ng scheduler ang lokal na solusyon sa bagong block. Kung mas mahusay ang lokal na quality, agad na nag-forge ang node sa halip na hintayin ang orihinal na deadline. Tinitiyak nito na ang mga miner ay hindi makakakuha ng kalamangan sa pamamagitan lamang ng pag-adjust ng mga lokal na orasan; ang pinakamahusay na solusyon ang laging mananalo, pinapanatili ang fairness at network security.

---

## 8. Pagsusuri sa Seguridad

### 8.1 Modelo ng Banta

Ang PoCX ay nagmo-model ng mga adversary na may malaki ngunit bounded na mga kakayahan. Maaaring subukan ng mga attacker na mag-overload sa network ng mga invalid transaction, malformed block, o fabricated proof upang i-stress-test ang mga validation path. Malayang maaari nilang manipulahin ang kanilang mga lokal na orasan at maaari nilang subukang samantalahin ang mga edge case sa consensus behavior tulad ng timestamp handling, difficulty adjustment dynamics, o mga patakaran sa reorganization. Inaasahan din na i-probe ng mga adversary ang mga pagkakataon na muling isulat ang kasaysayan sa pamamagitan ng mga targeted chain fork.

Ipinapalagay ng modelo na walang iisang partido ang kumokontrol ng karamihan ng kabuuang network storage capacity. Tulad ng anumang resource-based consensus mechanism, ang isang 51% capacity attacker ay unilaterally na maaaring mag-reorganize ng chain; ang pundamental na limitasyong ito ay hindi tiyak sa PoCX. Ipinapalagay din ng PoCX na ang mga attacker ay hindi makakapag-compute ng plot data na mas mabilis kaysa sa maaaring basahin ng mga matapat na miner mula sa disk. Tinitiyak ng scaling schedule (Seksyon 6) na ang computational gap na kinakailangan para sa seguridad ay lumalaki sa paglipas ng panahon habang umuunlad ang hardware.

Sinusuri ng mga sumusunod na seksyon ang bawat pangunahing klase ng atake nang detalyado at inilalarawan ang mga countermeasure na naka-build sa PoCX.

### 8.2 Mga Capacity Attack

Tulad ng PoW, ang isang attacker na may majority capacity ay maaaring muling isulat ang kasaysayan (isang 51% attack). Ang pagkamit nito ay nangangailangan ng pagkuha ng physical storage footprint na mas malaki kaysa sa matapat na network—isang mamahaling at logistically demanding na gawain. Kapag nakuha na ang hardware, mababa ang operating cost, ngunit ang paunang investment ay lumilikha ng malakas na economic incentive na kumilos nang matapat: ang pagsira sa chain ay makakasira sa halaga ng sariling asset base ng attacker.

Iniiwasan din ng PoC ang nothing-at-stake issue na nauugnay sa PoS. Bagama't ang mga miner ay maaaring mag-scan ng mga plot laban sa maraming nakikipagkumpitensyang fork, ang bawat scan ay kumokonsumo ng tunay na oras—karaniwang sa order ng mga sampung segundo bawat chain. Sa 120-segundong block interval, likas nitong nililimitahan ang multi-fork mining, at ang pagtatangkang mag-mine ng maraming fork nang sabay-sabay ay nagpapababa ng performance sa lahat ng mga ito. Ang fork mining ay samakatuwid hindi libre; ito ay pundamentally na nililimitahan ng I/O throughput.

Kahit na ang hinaharap na hardware ay nagpahintulot ng halos-instant plot scanning (hal., high-speed SSD), ang isang attacker ay haharap pa rin sa malaking physical resource requirement upang kontrolin ang karamihan ng network capacity, na ginagawang mahal at logistically challenging ang isang 51%-style attack.

Sa wakas, ang mga capacity attack ay mas mahirap i-rent kaysa sa mga hashpower attack. Ang GPU compute ay maaaring makuha on demand at i-redirect sa anumang PoW chain nang instant. Sa kaibahan, ang PoC ay nangangailangan ng physical hardware, time-intensive plotting, at patuloy na mga I/O operation. Ang mga constraint na ito ay ginagawang hindi gaanong feasible ang mga short-term, opportunistic attack.

### 8.3 Mga Timing Attack

Ang timing ay may mas kritikal na papel sa Proof of Capacity kaysa sa Proof of Work. Sa PoW, ang mga timestamp ay pangunahing nakakaimpluwensya sa difficulty adjustment; sa PoC, tinutukoy nila kung ang deadline ng isang miner ay lumipas na at samakatuwid kung ang isang block ay eligible para sa forging. Ang mga deadline ay sinusukat kumpara sa timestamp ng parent block, ngunit ang lokal na orasan ng node ay ginagamit upang hatulan kung ang isang incoming block ay masyadong malayo sa hinaharap. Sa dahilang ito ang PoCX ay nagpapatupad ng mahigpit na timestamp tolerance: ang mga block ay hindi maaaring lumihis ng higit sa 15 segundo mula sa lokal na orasan ng node (kumpara sa 2-oras na window ng Bitcoin). Ang limitasyong ito ay gumagana sa parehong direksyon—ang mga block na masyadong malayo sa hinaharap ay ni-reject, at ang mga node na may mabagal na orasan ay maaaring maling i-reject ang mga valid incoming block.

Samakatuwid dapat i-synchronize ng mga node ang kanilang mga orasan gamit ang NTP o isang katumbas na time source. Sinasadyang iwasan ng PoCX ang pag-asa sa mga network-internal time source upang maiwasan ang mga attacker na manipulahin ang perceived network time. Sinusubaybayan ng mga node ang kanilang sariling drift at naglalabas ng mga babala kung ang lokal na orasan ay nagsisimulang lumihis mula sa mga kamakailang block timestamp.

Ang clock acceleration—pagpapatakbo ng mabilis na lokal na orasan upang mag-forge nang bahagyang mas maaga—ay nagbibigay lamang ng marginal na benepisyo. Sa loob ng allowed tolerance, tinitiyak ng defensive forging (Seksyon 7.3) na ang isang miner na may mas mahusay na solusyon ay agad na magpa-publish sa pagkakita ng isang inferior na maagang block. Ang mabilis na orasan ay tumutulong lamang sa isang miner na i-publish ang isang already-winning solution ng ilang segundo nang mas maaga; hindi nito mako-convert ang isang inferior na proof sa isang panalong isa.

Ang mga pagtatangkang manipulahin ang difficulty sa pamamagitan ng mga timestamp ay bounded ng ±20% per-block adjustment cap at isang 24-block rolling window, pinipigilan ang mga miner na makabuluhang maimpluwensyahan ang difficulty sa pamamagitan ng mga short-term timing game.

### 8.4 Mga Time-Memory Tradeoff Attack

Ang mga time-memory tradeoff ay sumusubok na bawasan ang mga kinakailangan sa storage sa pamamagitan ng pag-recompute ng mga bahagi ng plot on demand. Ang mga nakaraang sistema ng Proof of Capacity ay vulnerable sa mga ganitong atake, lalo na ang POC1 scoop-imbalance flaw at ang POC2 XOR-transpose compression attack (Seksyon 2.4). Parehong sinamantala ang mga asymmetry sa kung gaano kamahal ang pag-regenerate ng ilang bahagi ng plot data, na nagpapahintulot sa mga adversary na bawasan ang storage habang nagbabayad lamang ng maliit na computational penalty. Gayundin, ang mga alternatibong plot format sa PoC2 ay dumaranas ng mga katulad na kahinaan sa TMTO; ang isang prominenteng halimbawa ay ang Chia, kung saan ang plot format ay maaaring arbitrary na bawasan ng factor na higit sa 4.

Ganap na inaalis ng PoCX ang mga attack surface na ito sa pamamagitan ng nonce construction at warp format nito. Sa loob ng bawat nonce, ang final diffusion step ay nagha-hash ng fully computed buffer at nagba-XOR ng resulta sa lahat ng byte, tinitiyak na ang bawat bahagi ng buffer ay nakadepende sa bawat iba pang bahagi at hindi maaaring i-shortcut. Pagkatapos, inilalapat ang PoC2 shuffle, na nagpapalit ng lower at upper halves ng bawat scoop, ine-equalize ang computational cost ng pag-recover ng anumang scoop.

Karagdagang inaalis ng PoCX ang POC2 XOR-transpose compression attack sa pamamagitan ng pagkuha ng hardened X1 format nito, kung saan ang bawat scoop ay ang XOR ng isang direkta at isang transposed na posisyon sa mga paired warp; ito ay nag-i-interlock ng bawat scoop sa isang buong row at isang buong column ng underlying X0 data, ginagawang nangangailangan ang reconstruction ng libu-libong buong nonce at sa gayon ay ganap na inaalis ang asymmetric time-memory tradeoff.

Bilang resulta, ang pag-iimbak ng buong plot ang tanging computationally viable na estratehiya para sa mga miner. Walang kilalang shortcut—maging partial plotting, selective regeneration, structured compression, o hybrid compute-storage approach—ang nagbibigay ng makabuluhang kalamangan. Tinitiyak ng PoCX na ang mining ay nananatiling mahigpit na storage-bound at na ang kapasidad ay sumasalamin sa tunay, pisikal na commitment.

### 8.5 Mga Assignment Attack

Gumagamit ang PoCX ng deterministic state machine upang pamahalaan ang lahat ng plot-to-forger assignment. Ang bawat assignment ay dumadaan sa mga maayos na na-define na state—UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED—na may mga enforced activation at revocation delay. Tinitiyak nito na ang isang miner ay hindi maaaring agad na baguhin ang mga assignment upang mandaya sa sistema o mabilis na magpalit ng forging authority.

Dahil ang lahat ng transition ay nangangailangan ng mga cryptographic proof—partikular, mga signature ng may-ari ng plot na verifiable laban sa input UTXO—maaaring magtiwala ang network sa legitimacy ng bawat assignment. Ang mga pagtatangkang i-bypass ang state machine o mag-forge ng mga assignment ay awtomatikong ni-reject sa panahon ng consensus validation. Ang mga replay attack ay gayundin napipigilan ng standard Bitcoin-style transaction replay protection, tinitiyak na ang bawat assignment action ay natatanging nakatali sa isang valid, unspent input.

Ang kombinasyon ng state-machine governance, enforced delay, at cryptographic proof ay ginagawang practically imposible ang assignment-based cheating: ang mga miner ay hindi maaaring mag-hijack ng mga assignment, magsagawa ng rapid reassignment sa panahon ng mga block race, o lumampas sa mga revocation schedule.

### 8.6 Seguridad ng Signature

Ang mga block signature sa PoCX ay nagsisilbing isang kritikal na link sa pagitan ng isang proof at ng effective forging key, tinitiyak na tanging mga awtorisadong miner lamang ang maaaring mag-produce ng mga valid block.

Upang maiwasan ang mga malleability attack, ang mga signature ay hindi kasama sa block hash computation. Inaalis nito ang mga panganib ng malleable signature na maaaring makasira sa validation o magpahintulot ng mga block replacement attack.

Upang mapigilan ang mga denial-of-service vector, ang mga signature at public key size ay fixed—65 byte para sa compact signature at 33 byte para sa compressed public key—pinipigilan ang mga attacker na mag-inflate ng mga block upang mag-trigger ng resource exhaustion o pabagalin ang network propagation.

---

## 9. Implementasyon

Ang PoCX ay implemented bilang isang modular extension sa Bitcoin Core, na ang lahat ng kaugnay na code ay naka-contain sa sarili nitong dedikadong subdirectory at ina-activate sa pamamagitan ng isang feature flag. Ang disenyo na ito ay nagpapanatili ng integridad ng orihinal na code, na nagpapahintulot sa PoCX na ma-enable o ma-disable nang malinis, na nagpapasimple ng testing, auditing, at pananatiling in sync sa mga upstream change.

Ang integrasyon ay umaapekto lamang sa mga essential point na kinakailangan upang suportahan ang Proof of Capacity. Ang block header ay pinalawak upang isama ang mga field na tiyak sa PoCX, at ang consensus validation ay iniayon upang iproseso ang mga storage-based proof kasama ang mga tradisyunal na Bitcoin check. Ang forging system, na responsable para sa pamamahala ng mga deadline, scheduling, at miner submission, ay ganap na naka-contain sa loob ng mga PoCX module, habang ang mga RPC extension ay naglalantad ng mining at assignment functionality sa mga external client. Para sa mga user, ang wallet interface ay pinahusay upang pamahalaan ang mga assignment sa pamamagitan ng mga OP_RETURN transaction, na nagpapagana ng seamless interaction sa mga bagong consensus feature.

Lahat ng consensus-critical operation ay implemented sa deterministic C++ na walang external dependency, tinitiyak ang cross-platform consistency. Ginagamit ang Shabal256 para sa hashing, habang ang Time Bending at quality calculation ay umaasa sa fixed-point arithmetic at 256-bit operation. Ang mga cryptographic operation tulad ng signature verification ay gumagamit ng kasalukuyang secp256k1 library ng Bitcoin Core.

Sa pamamagitan ng paghihiwalay ng PoCX functionality sa ganitong paraan, ang implementasyon ay nananatiling auditable, maintainable, at ganap na compatible sa patuloy na development ng Bitcoin Core, na nagpapakita na ang isang pundamentally bagong storage-bound consensus mechanism ay maaaring mag-coexist sa isang mature proof-of-work codebase nang hindi naaabala ang integridad o usability nito.

---

## 10. Mga Parameter ng Network

Bumubuo ang PoCX sa network infrastructure ng Bitcoin at ginagamit ulit ang chain parameter framework nito. Upang suportahan ang capacity-based mining, mga block interval, assignment handling, at plot scaling, maraming parameter ang pinalawak o na-override. Kasama rito ang block time target, initial subsidy, halving schedule, mga activation at revocation delay ng assignment, pati na rin ang mga network identifier tulad ng magic byte, port, at Bech32 prefix. Ang mga testnet at regtest environment ay karagdagang nag-aadjust ng mga parameter na ito upang paganahin ang rapid iteration at low-capacity testing.

Ang mga talahanayan sa ibaba ay nagbubuod ng mga resultang mainnet, testnet, at regtest setting, na nagha-highlight kung paano inaangkop ng PoCX ang mga core parameter ng Bitcoin sa isang storage-bound consensus model.

### 10.1 Mainnet

| Parameter | Halaga |
|-----------|-------|
| Magic byte | `0xa7 0x3c 0x91 0x5e` |
| Default port | 8888 |
| Bech32 HRP | `pocx` |
| Target na block time | 120 segundo |
| Panimulang subsidy | 10 BTC |
| Halving interval | 1050000 block (~4 na taon) |
| Kabuuang supply | ~21 milyong BTC |
| Assignment activation | 30 block |
| Assignment revocation | 720 block |
| Rolling window | 24 block |

### 10.2 Testnet

| Parameter | Halaga |
|-----------|-------|
| Magic byte | `0x6d 0xf2 0x48 0xb3` |
| Default port | 18888 |
| Bech32 HRP | `tpocx` |
| Target na block time | 120 segundo |
| Ibang mga parameter | Pareho sa mainnet |

### 10.3 Regtest

| Parameter | Halaga |
|-----------|-------|
| Magic byte | `0xfa 0xbf 0xb5 0xda` |
| Default port | 18444 |
| Bech32 HRP | `rpocx` |
| Target na block time | 1 segundo |
| Halving interval | 500 block |
| Assignment activation | 4 block |
| Assignment revocation | 8 block |
| Low-capacity mode | Naka-enable (~4 MB plot) |

---

## 11. Mga Kaugnay na Gawain

Sa mga nakaraang taon, ilang blockchain at consensus project ang nag-explore ng storage-based o hybrid mining model. Bumubuo ang PoCX sa lineage na ito habang nagpapakilala ng mga pagpapahusay sa seguridad, kahusayan, at compatibility.

**Burstcoin / Signum.** Ipinakilala ng Burstcoin ang unang praktikal na sistema ng Proof-of-Capacity (PoC) noong 2014, na nagde-define ng mga pangunahing konsepto tulad ng mga plot, nonce, scoop, at deadline-based mining. Ang mga kahalili nito, lalo na ang Signum (dating Burstcoin), ay nagpalawak ng ecosystem at kalaunan ay nag-evolve sa tinatawag na Proof-of-Commitment (PoC+), na pinagsasama ang storage commitment sa opsyonal na staking upang maimpluwensyahan ang effective capacity. Minana ng PoCX ang storage-based mining foundation mula sa mga proyektong ito, ngunit makabuluhang lumihis sa pamamagitan ng isang hardened plot format (XOR-transpose encoding), dynamic plot-work scaling, deadline smoothing ("Time Bending"), at isang flexible assignment system—lahat habang naka-anchor sa Bitcoin Core codebase sa halip na nagpapanatili ng standalone network fork.

**Chia.** Nagpapatupad ang Chia ng Proof of Space and Time, na pinagsasama ang disk-based storage proof sa isang time component na ipinatutupad sa pamamagitan ng Verifiable Delay Function (VDF). Ang disenyo nito ay tumutugon sa ilang alalahanin tungkol sa proof reuse at fresh challenge generation, na naiiba sa classic PoC. Hindi na-adopt ng PoCX ang time-anchored proof model na iyon; sa halip, pinapanatili nito ang isang storage-bound consensus na may predictable interval, na na-optimize para sa long-term compatibility sa UTXO economics at Bitcoin-derived tooling.

**Spacemesh.** Iminumungkahi ng Spacemesh ang isang Proof-of-Space-Time (PoST) scheme gamit ang isang DAG-based (mesh) network topology. Sa modelong ito, ang mga kalahok ay dapat periodically na patunayan na ang allocated storage ay nananatiling intact sa paglipas ng panahon, sa halip na umasa sa isang solong precomputed dataset. Ang PoCX, sa kaibahan, ay nagve-verify ng storage commitment sa block time lamang—na may mga hardened plot format at rigorous proof validation—iniiwasan ang overhead ng mga continuous storage proof habang pinapanatili ang kahusayan at decentralization.

---

## 12. Konklusyon

Ipinakikita ng Bitcoin-PoCX na ang energy-efficient consensus ay maaaring ma-integrate sa Bitcoin Core habang pinapanatili ang mga security property at economic model. Kasama sa mga pangunahing kontribusyon ang XOR-transpose encoding (pinipilit ang mga attacker na mag-compute ng 4096 nonce bawat lookup, inaalis ang compression attack), ang Time Bending algorithm (ang distribution transformation ay nagpapababa ng block time variance), ang forging assignment system (ang OP_RETURN-based delegation ay nagpapagana ng non-custodial pool mining), dynamic scaling (naka-align sa mga halving upang mapanatili ang mga security margin), at minimal integration (feature-flagged code na nakahiwalay sa isang dedikadong direktoryo).

Ang sistema ay kasalukuyang nasa yugto ng testnet. Ang kapangyarihan sa mining ay nakukuha mula sa storage capacity sa halip na hash rate, binabawasan ang pagkonsumo ng enerhiya ng mga order of magnitude habang pinapanatili ang napatunayang economic model ng Bitcoin.

---

## Mga Sanggunian

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Lisensya**: MIT
**Organisasyon**: Proof of Capacity Consortium
**Katayuan**: Yugto ng Testnet
