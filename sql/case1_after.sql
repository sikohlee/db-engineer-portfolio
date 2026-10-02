-- 사례 1. 종합성적 조회 쿼리 - 개선 후 (가상, 일반화된 테이블명)
-- 대상 학생의 성적을 WITH절로 한 번만 읽고, 영역별 점수를 조건부 집계로 계산
WITH RSLT AS (                         -- 성적 테이블은 1회, 대상 학생만 조회
    SELECT R.SUBJ_DIV, R.SHTM, R.CREDIT, R.POINT
      FROM SUBJ_RESULT R
     WHERE R.YY = :yy
       AND R.STD_NO = :std_no
), STUDY AS (
    SELECT ROUND(SUM(CREDIT*POINT)/SUM(CREDIT), 2) AS STUDY_SCR
      FROM RSLT
     WHERE SUBJ_DIV IN (SELECT CD FROM COMMON_CODE
                         WHERE GRP_CD = 'SUBJ_DIV' AND ATTR1 = 'G')
), PRAC AS (
    SELECT ROUND(NVL(SUM(DECODE(SHTM, '10', POINT)), 0)*0.2
               + NVL(SUM(DECODE(SHTM, '20', POINT)), 0)*0.2
               + NVL(SUM(DECODE(SHTM, '21', POINT)), 0)*0.6, 2) AS PRAC_SCR
      FROM RSLT
     WHERE SUBJ_DIV = 'P'
), LIFE AS (
    SELECT (NVL(MAX(DECODE(SHTM, '10', POINT)), 0)*2
          + NVL(MAX(DECODE(SHTM, '20', POINT)), 0)*2
          + NVL(MAX(DECODE(SHTM, '21', POINT)), 0)) / NULLIF(SUM(CREDIT), 0) AS LIFE_SCR
      FROM RSLT
     WHERE SUBJ_DIV = 'L'
), FIT AS (                            -- 스칼라 서브쿼리 > 조인
    SELECT SUM(G.POINT)/2 AS FIT_SCR
      FROM FITNESS_RESULT FR
      JOIN FIT_GRADE G
        ON G.YY = FR.YY AND G.SHTM = FR.SHTM
       AND NVL(FR.TOT_SCR, 0) BETWEEN G.SCR_FROM AND G.SCR_TO
     WHERE FR.YY = :yy
       AND FR.STD_NO = :std_no
), RNK AS (
    SELECT AVG(ALL_RANK) AS TOT_RANK
      FROM TOTAL_RANK
     WHERE STD_NO = :std_no
)
SELECT :yy AS YY
     , T.STD_NO, T.STD_NM
     , TO_CHAR(S.STUDY_SCR, 'FM990.00') AS STUDY_SCR
     , TO_CHAR(P.PRAC_SCR,  'FM990.00') AS PRAC_SCR
     , TO_CHAR(F.FIT_SCR,   'FM990.00') AS FIT_SCR
     , TO_CHAR(L.LIFE_SCR,  'FM990.00') AS LIFE_SCR
     , TO_CHAR(S.STUDY_SCR*0.5 + P.PRAC_SCR*0.25
             + F.FIT_SCR*0.15 + L.LIFE_SCR*0.1, 'FM990.00') AS TOT_SCR
     , TO_CHAR(K.TOT_RANK, 'FM990.0') AS TOT_RANK
  FROM STD_MASTER T
 CROSS JOIN STUDY S
 CROSS JOIN PRAC  P
 CROSS JOIN FIT   F
 CROSS JOIN LIFE  L
 CROSS JOIN RNK   K
 WHERE T.STD_NO = :std_no;
