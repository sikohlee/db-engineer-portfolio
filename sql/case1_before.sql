-- 사례 1. 종합성적 조회 쿼리 - 개선 전 (가상, 일반화된 테이블명)
-- 영역별 인라인뷰가 각각 기수 전체를 집계하고, 같은 서브쿼리가 반복됨
SELECT :yy AS YY
     , M.STD_NO, M.STD_NM
     , TO_CHAR(M.STUDY_SCR, 'FM990.00') AS STUDY_SCR
     , TO_CHAR(P.PRAC_SCR,  'FM990.00') AS PRAC_SCR
     , TO_CHAR(F.FIT_SCR,   'FM990.00') AS FIT_SCR
     , TO_CHAR(L.LIFE_SCR,  'FM990.00') AS LIFE_SCR
     , TO_CHAR(M.STUDY_SCR*0.5 + P.PRAC_SCR*0.25
             + F.FIT_SCR*0.15 + L.LIFE_SCR*0.1, 'FM990.00') AS TOT_SCR
     , TO_CHAR(K.TOT_RANK, 'FM990.0') AS TOT_RANK
  FROM
       --  학업 점수
       (SELECT A.STD_NO, A.STD_NM, B.AVG_POINT AS STUDY_SCR
          FROM (SELECT S.STD_NO, S.STD_NM
                     , FN_CODE_NM('DEPT', S.DEPT_CD) AS DEPT_NM   -- 미사용
                     , FN_CODE_NM('STAT', S.STAT_CD) AS STAT_NM   -- 미사용
                  FROM STD_MASTER S, DEPT_INFO D
                 WHERE S.DEPT_CD = D.DEPT_CD(+)) A,
               (SELECT R.STD_NO
                     , ROUND(SUM(R.CREDIT*R.POINT)/SUM(R.CREDIT), 2) AS AVG_POINT
                     , RANK() OVER (ORDER BY SUM(R.CREDIT*R.POINT)/SUM(R.CREDIT) DESC) AS RNK  -- 미사용
                  FROM SUBJ_RESULT R
                 WHERE R.YY = :yy
                   AND R.SUBJ_DIV IN (SELECT CD FROM COMMON_CODE
                                       WHERE GRP_CD = 'SUBJ_DIV' AND ATTR1 = 'G')
                   AND R.STD_NO IN (SELECT S2.STD_NO FROM STD_MASTER S2
                                     WHERE S2.GRDT_NO = (SELECT GRDT_NO FROM STD_MASTER
                                                          WHERE STD_NO = :std_no))
                 GROUP BY R.STD_NO) B          -- 기수 전체 집계
         WHERE A.STD_NO = B.STD_NO
           AND A.STD_NO = :std_no              -- 마지막에 1명만 선택
         ORDER BY B.AVG_POINT DESC) M,
       --  실습 점수
       (SELECT C.STD_NO
             , ROUND(C.T1*0.2 + C.T2*0.2 + C.SUMMER*0.6, 2) AS PRAC_SCR
             , (SELECT COUNT(*)                -- 같은 집계를 한 번 더 수행 (미사용)
                  FROM (SELECT R2.STD_NO FROM SUBJ_RESULT R2
                         WHERE R2.YY = :yy AND R2.SUBJ_DIV = 'P'
                           AND R2.STD_NO IN (SELECT S3.STD_NO FROM STD_MASTER S3
                                              WHERE S3.GRDT_NO = (SELECT GRDT_NO FROM STD_MASTER
                                                                   WHERE STD_NO = :std_no))
                         GROUP BY R2.STD_NO)) AS CNT
          FROM (SELECT R.STD_NO
                     , NVL(SUM(DECODE(R.SHTM, '10', R.POINT)), 0) AS T1
                     , NVL(SUM(DECODE(R.SHTM, '20', R.POINT)), 0) AS T2
                     , NVL(SUM(DECODE(R.SHTM, '21', R.POINT)), 0) AS SUMMER
                  FROM SUBJ_RESULT R
                 WHERE R.YY = :yy AND R.SUBJ_DIV = 'P'
                   AND R.STD_NO IN (SELECT S2.STD_NO FROM STD_MASTER S2
                                     WHERE S2.GRDT_NO = (SELECT GRDT_NO FROM STD_MASTER
                                                          WHERE STD_NO = :std_no))
                 GROUP BY R.STD_NO) C
         WHERE C.STD_NO = :std_no) P,
       --  체력 점수: 행마다 환산표 스칼라 서브쿼리 실행
       (SELECT SUM(X.FIT_POINT)/2 AS FIT_SCR
          FROM (SELECT FR.SHTM
                     , (SELECT G.POINT FROM FIT_GRADE G
                         WHERE G.YY = FR.YY AND G.SHTM = FR.SHTM
                           AND NVL(FR.TOT_SCR, 0) BETWEEN G.SCR_FROM AND G.SCR_TO) AS FIT_POINT
                     , FN_CODE_NM('SHTM', FR.SHTM) AS SHTM_NM   -- 미사용
                  FROM FITNESS_RESULT FR, STD_MASTER S
                 WHERE FR.STD_NO = S.STD_NO
                   AND FR.YY = :yy
                   AND S.STD_NO = :std_no) X) F,
       --  생활 점수
       (SELECT (NVL(Y.T1, 0)*2 + NVL(Y.T2, 0)*2 + NVL(Y.SUMMER, 0))
             / (SELECT SUM(H.CREDIT) FROM SUBJ_RESULT H
                 WHERE H.YY = :yy AND H.SUBJ_DIV = 'L'
                   AND H.STD_NO = Y.STD_NO) AS LIFE_SCR
          FROM (SELECT R.STD_NO
                     , MAX(DECODE(R.SHTM, '10', R.POINT)) AS T1
                     , MAX(DECODE(R.SHTM, '20', R.POINT)) AS T2
                     , MAX(DECODE(R.SHTM, '21', R.POINT)) AS SUMMER
                  FROM SUBJ_RESULT R, STD_MASTER S
                 WHERE R.STD_NO = S.STD_NO
                   AND R.YY = :yy AND R.SUBJ_DIV = 'L'
                   AND S.GRDT_NO = (SELECT GRDT_NO FROM STD_MASTER WHERE STD_NO = :std_no)
                   AND S.STD_NO = :std_no
                 GROUP BY R.STD_NO) Y) L,
       --  서열
       (SELECT AVG(ALL_RANK) AS TOT_RANK
          FROM TOTAL_RANK
         WHERE STD_NO = :std_no
         GROUP BY STD_NO) K;
