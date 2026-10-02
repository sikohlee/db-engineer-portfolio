-- 사례 3. 데이터 변경 작업 절차 및 오변경 복구 (일반화된 테이블명)
-- 특정 학생 1명의 성적을 수정하려다 조건 누락으로
-- 전공코드는 다르면서 과목코드는 같은 다른 과목도 변경된 상황을 재구성

-- 1. 사전 백업
CREATE TABLE COURSE_GRADE_BAK_20230615 AS
SELECT * FROM COURSE_GRADE;

-- 2. 사전 SELECT로 대상 건수 확인
SELECT COUNT(*) FROM COURSE_GRADE
 WHERE YY = '2023' AND TERM = '1'            -- 23년 1학기
   AND STD_NO = '20334' AND SUBJ_CD = '10553';  -- 20334번 학생의 10553과목

-- 3. 사고: DEPT_CD 조건 누락
--     이후 전공코드가 다른데 과목코드는 같은 또 다른 과목도 변경 처리된 것을 파악
UPDATE COURSE_GRADE
   SET GRADE = 'B+', POINT = 3.5
 WHERE YY = '2023' AND TERM = '1'
   AND STD_NO = '20334' AND SUBJ_CD = '10553';
   -- AND DEPT_CD = '0029'   누락

-- 복구 방법 A: 사전 백업본으로 원복
UPDATE COURSE_GRADE G
   SET (GRADE, POINT) = (SELECT B.GRADE, B.POINT
                           FROM COURSE_GRADE_BAK_20230615 B
                          WHERE B.STD_NO  = G.STD_NO
                            AND B.SUBJ_CD = G.SUBJ_CD
                            AND B.YY    = G.YY
                            AND B.TERM    = G.TERM
                            AND B.DEPT_CD = G.DEPT_CD)
 WHERE G.YY = '2023' AND G.TERM = '1'
   AND G.STD_NO = '20334' AND SUBJ_CD = '10553';
COMMIT;

-- 복구 방법 B: Flashback Query로 변경 이전 시점 데이터 조회 후 복구
-- 10분 전 시점의 데이터 확인
SELECT STD_NO, SUBJ_CD, GRADE, POINT
  FROM COURSE_GRADE AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '10' MINUTE)
 WHERE YY = '2023' AND TERM = '1'
   AND STD_NO = '20334' AND SUBJ_CD = '10553';

-- 해당 시점 데이터로 원복
UPDATE COURSE_GRADE G
   SET (GRADE, POINT) = (SELECT F.GRADE, F.POINT
                           FROM COURSE_GRADE AS OF TIMESTAMP
                                (SYSTIMESTAMP - INTERVAL '10' MINUTE) F
                          WHERE F.STD_NO  = G.STD_NO
                            AND F.SUBJ_CD = G.SUBJ_CD
                            AND F.YY    = G.YY
                            AND F.TERM    = G.TERM
                            AND F.DEPT_CD = G.DEPT_CD)
 WHERE G.YY = '2023' AND G.TERM = '1'
   AND G.STD_NO = '20334' AND G.SUBJ_CD = '10553';
COMMIT;

-- 원복 후 원래 의도했던 1건 수정을 올바른 조건(DEPT_CD 포함)으로 다시 수행
