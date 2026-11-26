# Google Play 정식 출시 체크리스트

2026-11-26 기준으로 정리했다. 정책은 바뀔 수 있으니 올리기 전에 Play Console 안내를 다시 확인한다.

## 이미 된 것

- [x] 대상 API 36 (Android 16). 2026-08-31부터 새 앱과 업데이트에 필요한 기준
- [x] 앱 안에서 계정 삭제 (설정 > 계정 삭제). 기록, 자산, 고정지출, 알림, 프로필과 로그인 계정을 지운다
- [x] 출시용 서명 설정. `android/key.properties` 가 있으면 그 키로, 없으면 시험용 디버그 키로 서명한다
- [x] 출시 빌드의 App Check 는 Play Integrity 를 쓴다. 디버그 토큰은 시험 빌드에서만 쓴다
- [x] 개인정보처리방침 초안 ([privacy-policy.md](./privacy-policy.md))
- [x] Firestore 보안 규칙과 에뮬레이터 시험 184개

## 출시 전에 정해야 하는 것

| 항목 | 왜 | 되돌릴 수 있나 |
| --- | --- | --- |
| 패키지 이름 | 지금은 `com.example.mm_app` 이다. Play 는 `com.example` 로 시작하는 이름을 받지 않는다 | 없다. 한 번 올리면 바꿀 수 없다 |
| 개발자 계정 | 누구 이름으로 올릴지. 개인 계정은 등록비 25달러와 신원 확인이 필요하다 | 어렵다 |
| 팀 동의 | 팀원과 멘토 코드, 기획이 들어간 앱을 상용으로 낼지 | - |
| 투자 정보 기능 | 사용자 맞춤 투자 정보가 유사투자자문업 신고 대상인지 확인이 필요하다. 확인 전에는 일반 정보만 보이게 줄이는 방법도 있다 | 있다 |
| 앱 이름 | Liqua 상표가 이미 있는지 확인 | 있다 |

## 패키지 이름을 정한 뒤 할 일

1. `android/app/build.gradle.kts` 의 `applicationId`, `namespace` 와 Kotlin 패키지 경로를 바꾼다
2. Firebase 콘솔에 새 패키지 이름으로 Android 앱을 추가하고 `google-services.json` 을 다시 받는다
3. `flutterfire configure` 로 `lib/firebase_options.dart` 를 다시 만든다
4. 출시용 업로드 키를 만든다 (아래)
5. Firebase 에 디버그 키, 업로드 키, Play 앱 서명 키의 SHA-1 과 SHA-256 을 모두 등록한다. 빠지면 Google 로그인이 실패한다
6. Google Cloud 콘솔에서 API 키를 이 패키지와 서명 키로만 쓰게 제한한다

## 업로드 키 만들기

```bash
keytool -genkeypair -v -keystore ~/liqua-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

`android/key.properties` 를 만든다. 이 파일과 `.jks` 는 저장소에 올리지 않는다(`.gitignore` 에 있음).

```
storeFile=/home/<사용자>/liqua-upload.jks
storePassword=<비밀번호>
keyAlias=upload
keyPassword=<비밀번호>
```

키 파일과 비밀번호는 저장소 밖 두 곳에 따로 보관한다. Play 앱 서명을 쓰면 업로드 키를 잃어도 재설정할 수 있다.

```bash
flutter build appbundle --release
# build/app/outputs/bundle/release/app-release.aab 를 Play Console 에 올린다
```

## Firebase 콘솔

- [ ] Firestore 규칙에 `firestore.rules` 를 게시
- [ ] App Check 에 Play Integrity 등록, Firestore 와 AI Logic 에 적용
- [ ] Firestore 데이터 위치 확인 후 개인정보처리방침에 적기
- [ ] Gemini 사용량 한도 확인. 무료 등급을 넘으면 결제 계정이 필요하다

## Play Console

- [ ] 개인정보처리방침을 공개 웹 주소에 올리고 등록
- [ ] 계정 삭제 웹 주소 등록. 앱 밖에서도 삭제를 요청할 수 있어야 한다 (문의 메일이나 신청 양식)
- [ ] 데이터 보안 양식: 수집 항목은 [privacy-policy.md](./privacy-policy.md) 1번 표와 같게
- [ ] 금융 기능 신고서: 개인 자산 관리(가계부) 앱으로 신고
- [ ] 알림 읽기 권한: 결제 기록이 핵심 기능이라는 설명과 시연 영상. 앱은 켜기 전에 무엇을 저장하고 버리는지 먼저 보여 준다
- [ ] 콘텐츠 등급 설문, 대상 연령, 광고 없음
- [ ] 스토어 등록정보: 짧은 설명 80자, 긴 설명, 아이콘 512px, 그래픽 이미지 1024×500, 휴대폰 스크린샷 2장 이상

## 비공개 테스트 (2023-11-13 이후 만든 개인 계정)

- [ ] 테스터 12명 이상이 14일 동안 연속으로 참여한 비공개 테스트
- [ ] 그 뒤 프로덕션 접근 신청

조직 계정은 이 조건이 없다.

## 참고

- [새 개인 개발자 계정의 테스트 요건](https://support.google.com/googleplay/android-developer/answer/14151465)
- [대상 API 수준 요건](https://developer.android.com/google/play/requirements/target-sdk)
- [계정 삭제 요건](https://support.google.com/googleplay/android-developer/answer/13327111)
