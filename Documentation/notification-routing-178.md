# 알림 상세 이동 검증 (#178)

## 서버 계약

heatguard-server main의 `NOTIFICATION_FILTER_CHANGELOG.md`, `app/endpoints.py`, `app/api.py`를 읽기 전용으로 확인했습니다.

- RECORD: RECORD_CREATED → resourceId의 기록 상세
- NOTICE: INQUIRY_ANSWERED → resourceId의 문의 상세
- EMERGENCY: EMERGENCY_ACKNOWLEDGED → 알림 상세, 현재 호출 ID가 resourceId와 일치할 때 상태 표시
- 미래/기타 이벤트: 서버가 NOTICE로 분류 → 알림 상세에 서버가 전달한 제목·날짜 표시
- ID 누락/빈 값: 잘못된 상세 API를 호출하지 않고 알림 상세로 이동

작업자 API에는 일반 공지 상세와 과거 긴급호출 상세 GET이 없습니다. 과거 알림을 눌러 새로운 호출을 생성하거나 다른 현재 호출을 대신 보여주지 않습니다.

## 확인 결과

- `sh scripts/test-notifications.sh`: 실제 Core 소스를 참조하는 macOS XCTest 12개 통과
- 서명된 iOS Simulator Debug 빌드 통과
- 실제 테스트 계정의 기록 알림 → 기록 상세 이동 회귀 확인
- iPhone 17e 별도 fixture 앱: 긴급 접수, 다른 호출 ID, 기타 공지, 대상 ID 누락 화면 확인
- fixture 앱의 변경된 App 진입점과 샘플 데이터는 제품 코드에 포함되지 않음
- CI에 알림 경로 XCTest 실행 추가

## 실제 데이터 검증 제한

테스트 계정의 EMERGENCY/NOTICE 알림 목록은 비어 있어 관리자 접수 알림 생성과 문의 답변 알림 생성부터 실제 클릭까지는 검증하지 못했습니다. 문의 상세 경로는 기존 경로를 유지하고 단위 테스트로 대상 ID 매핑을 확인했습니다. 첨부 스크린샷은 fixture 데이터로 실제 신규 상세 View를 실행한 화면입니다.
