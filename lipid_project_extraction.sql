declare @lipid_year int, @lipid_max_date nvarchar(10), @lipid_min_date nvarchar(10)

set @lipid_year=2009
set @lipid_max_date=cast((@lipid_year+1) as nvarchar)  + '-01-01'
set @lipid_min_date=cast((@lipid_year) as nvarchar)  + '-01-01'

-- compute the list of patient with their lab results
if OBJECT_ID(N'lab_vars_1', 'U') is not null
begin
	drop table lab_vars_1
end

select patient_id
, max(tc) tc, max(tc_date) tc_date
, max(tg) tg, max(tg_date) tg_date
, max(hdl) hdl, max(hdl_date) hdl_date
, max(ldl) ldl, max(ldl_date) ldl_date
, max(test_date) test_date
into lab_vars_1
	from (
select lab.patient_id
, case when tc.lid is not null then lab.TestResult_calc else null end tc
, case when tc.lid is not null then lab.PerformedDate else null end tc_date
, case when tg.lid is not null then lab.TestResult_calc else null end tg
, case when tg.lid is not null then lab.PerformedDate else null end tg_date
, case when hdl.lid is not null then lab.TestResult_calc else null end hdl
, case when hdl.lid is not null then lab.PerformedDate else null end hdl_date
, case when ldl.lid is not null then lab.TestResult_calc else null end ldl
, case when ldl.lid is not null then lab.PerformedDate else null end ldl_date
, lab.PerformedDate test_date
	from Lab 
left join
(select patient_id, max(lab_id) lid from Lab where DateCreated<convert(datetime, @lipid_max_date) and DateCreated>=convert(datetime, @lipid_min_date) and Name_calc='TOTAL CHOLESTEROL' group by patient_id) tc
on lab.Lab_ID=tc.lid
left join
(select patient_id, max(lab_id) lid from Lab where DateCreated<convert(datetime, @lipid_max_date) and DateCreated>=convert(datetime, @lipid_min_date) and Name_calc='TRIGLYCERIDES' group by patient_id) tg
on lab.Lab_ID=tg.lid
left join
(select patient_id, max(lab_id) lid from Lab where DateCreated<convert(datetime, @lipid_max_date) and DateCreated>=convert(datetime, @lipid_min_date) and Name_calc='HDL' group by patient_id) hdl
on lab.Lab_ID=hdl.lid
left join
(select patient_id, max(lab_id) lid from Lab where DateCreated<convert(datetime, @lipid_max_date) and DateCreated>=convert(datetime, @lipid_min_date) and Name_calc='LDL' group by patient_id) ldl
on lab.Lab_ID=ldl.lid
where 
tc.lid is not null 
or tg.lid is not null
or hdl.lid is not null
or ldl.lid is not null
) lab_value_list
group by patient_id


-- filter out pregnancy patient
if OBJECT_ID(N'lab_vars', 'U') is not null
begin
	drop table lab_vars
end

select lab_vars_1.* into lab_vars from lab_vars_1 
left join (
select distinct patient_id from 
(
select patient_id, DiagnosisCode_calc from EncounterDiagnosis
union
select patient_id, DiagnosisCode_calc from HealthCondition
) as condition
where DiagnosisCode_calc in (
'307.52','632','633','633.9','633.91','634','635','636','637','638',
'639','639.9','640','640','641','642','642.3','642.4','642.5',
'642.6','642.7','643','644','644','644.1','644.2','645','646',
'646.1','646.2','646.7','646.8','647','648','649','649.4','650',
'651.7','652.1','652.2','655','656','656','656.3','656.7','656.8','656.9',
'658','658.1','658.4','658.8','659.7','659.8','668','669.5','669.6',
'673.1','674.4','678','761.5','761.7','762.2','762.3','763',
'763.4','763.89','764','764','764.2','765.2','766.22','770.13',
'770.14','771.89','772','774.2','779.6','792.3','793.99','V22',
'V23.2','V23.86','V27','V27','V28.1','V72.40','V89.0','V89.02',
'658.8','66.62','68','69.01','69.02','69.51','69.52','72','72.4','72.5',
'72.51','72.52','72.53','72.54','72.6','72.8','72.9','73','73.1','73.5','73.51',
'73.59','73.9','73.93','74.3','74.91','75','75.3','75.32','75.33','75.34','75.35',
'75.36','75.38','762.8','762.9','89.5','92.17')
) mat_pt on lab_vars_1.Patient_ID=mat_pt.Patient_ID where mat_pt.Patient_ID is null

--exam in 6 month prior to test_date
if OBJECT_ID(N'exam_vars', 'U') is not null
begin
	drop table exam_vars
end

select Patient_ID,
max(bodyweight) bodyweight, 
max(bmi) bmi, max(height) height, max(sbp) sbp, max(dbp) dbp, max(waistcirc) waistcirc
into exam_vars
from 
(
select
exam.Patient_ID,
case when Exam1='Weight (kg)' then cast(exam.Result1_calc as numeric(5,0)) else null end bodyweight,
case when Exam1='BMI (kg/m^2)' then cast(exam.Result1_calc as numeric(5,0)) else null end bmi,
case when Exam1='Height (cm)' then cast(exam.Result1_calc as numeric(5,0)) else null end height,
case when Exam1='sBP (mmHg)' then cast(exam.Result1_calc as numeric(5,0)) else null end sbp,
case when Exam1='sBP (mmHg)' then cast(exam.Result1_calc as numeric(5,0)) else null end dbp,
case when Exam1='Waist Circumference (cm)' then cast(exam.Result1_calc as numeric(5,0)) else null end waistcirc
from exam, (
select exam.Patient_ID, max(exam.Exam_ID) eid
from lab_vars, exam 
where 
lab_vars.Patient_ID=exam.Patient_ID
and exam1 in ('Weight (kg)', 'BMI (kg/m^2)', 'Height (cm)','Waist Circumference (cm)','sBP (mmHg)')
and ((datediff(m, exam.DateCreated, lab_vars.test_date)<6
and exam.DateCreated<=lab_vars.test_date) or exam1='Height (cm)')
and exam.Result1_calc is not null
group by exam.Patient_ID, exam.exam1) latest_exam
where exam.Exam_ID=latest_exam.eid
) exam_data
group by Patient_ID


--diagnosis data and cvd in 2 year prior to test_date
if OBJECT_ID(N'condition_vars', 'U') is not null
begin
	drop table condition_vars
end

select Patient_ID,
max(diabetes) diabetes, max(hypertension) hypertension,
max(dyslipidemia) dyslipidemia, 
max(cad) cad, max(pad) pad, max(aaa) aaa, max(cvd) cvd 
into condition_vars
from (
select condition.patient_id,
case when DiagnosisCode_calc in ('Diabetes Mellitus') then 1 else 0 end diabetes,
case when DiagnosisCode_calc in ('Hypertension') then 1 else 0 end hypertension,
case when left(DiagnosisCode_calc,3) in ('272') then 1 else 0 end dyslipidemia,
case when left(DiagnosisCode_calc,3) in ('410','411','412','413','414') or DiagnosisCode_calc='429.2'
then 1 else 0 end cad,
case when DiagnosisCode_calc in (
'997.7','996.74','902.26','747.9','747.89','747.83',
'747.82','747.81','747.69','747.64','747.63','747.62',
'747.61','747.6','747.6','747.5','747.49','747.42',
'747.41','747.4','747.4','747.3','747.11','747.1',
'747.1','747','747','746.85','557.9','557.1',
'447.6','447.2','446.7','446.5','443.9','442.89',
'442.84','442.83','442.82','442.81','442.8','442.3',
'442','441','440.4','440.3','440.23','440.22','440.21',
'440.2','440','437.4','417.8','417.1','414.3','414.04','414',
'411.81','377.72','377.62','377.53','362.18','362.13','286.4','250.7',
'249.7','96.57','89.63','88.77','88.41','39.5','39.49','39.4',
'39.3','39.29','36.99','36.19','36.17','36.16','36.15','36.14',
'36.13','36.12','36.11','36.1','36.1','36.09','36.06','36.03',
'35.92','0.66','0.65','0.64','0.63','0.62','0.61','0.49',
'0.48','0.47','0.46','0.03') then 1 else 0 end pad,
case when DiagnosisCode_calc in (
'442.89','442.84','441.9','441.4','441.3','441','93','39.71','39.52',
'39.51','38.4','0.58') then 1 else 0 end aaa,
case when DiagnosisCode_calc in (
'V17.1','V12.54','997.02','900.01','900','900',
'447.6','447.2','446.7','443.21','442.81','440',
'437.4','437.3','437.1','436','435','433',
'337.01','227.5','194.5','99.64','89.56','88.41',
'39.8','39.74','39.7','39.53','39.5','39.22',
'38.1','21.06','0.67','0.63','0.61','0.21','0.01')
and datediff(m, condition.DateCreated, lab_vars.test_date)<24
then 1 else 0 end cvd
from 
lab_vars,
(
select patient_id, DiagnosisCode_calc, DateCreated from EncounterDiagnosis
union
select patient_id, DiagnosisCode_calc, DateCreated from HealthCondition
union
select patient_id, Disease as DiagnosisCode_calc, DateOfOnset as DateCreated from DiseaseCase
) as condition
where 
lab_vars.Patient_ID=condition.Patient_ID
and lab_vars.test_date>DateCreated
) diag_data
group by patient_id

--non statin medication
if OBJECT_ID(N'med_vars', 'U') is not null
begin
	drop table med_vars
end

select Patient_ID,
max(thiazides) thiazides, max(diuretics) diuretics, max(beta_blocker) beta_blocker, 
max(alpha_blocker) alpha_blocker, max(ace_inhibitor) ace_inhibitor, 
max(estrogen) estrogen, max(progestron) progestron,
max(hormone) hormone, max(corticosteroids) corticosteroids
into med_vars
from
(
select
Medication.Patient_ID,
case when Code_calc in (
'C02DA01','C03AA01','C03AA02','C03AA03','C03AA04','C03AA05','C03AA06','C03AA07','C03AA08','C03AA09','C03AA13','C03AB01','C03AB02','C03AB03','C03AB04','C03AB05','C03AB06','C03AB07','C03AB08','C03AB09','C03AH01','C03AH02','C03AX01','C07BA02','C07BA05','C07BA06','C07BA07','C07BA12','C07BA68','C07BB02','C07BB03','C07BB04','C07BB06','C07BB07','C07BB12','C07BB52','C07BG01','C07DA06','C07DB01')
then 1 else 0 end thiazides,
case when Code_calc in (
'C03CA01','C03CA02','C03CA03','C03CA04','C03CB01','C03CB02','C03CC01','C03CC02','C03CD01','C03CX01')
then 1 else 0 end diuretics,
case when Code_calc in (
'C07AA01','C07AA02','C07AA03','C07AA05','C07AA06','C07AA07','C07AA12','C07AA14','C07AA15','C07AA16','C07AA17','C07AA19','C07AA23','C07AA27','C07AA57','C07AB01','C07AB02','C07AB03','C07AB04','C07AB05','C07AB06','C07AB07','C07AB08','C07AB09','C07AB10','C07AB11','C07AB12','C07AB13','C07AB52','C07AB57','C07AG01','C07AG02','C07CA02','C07CA03','C07CA17','C07CA23','C07CB02','C07CB03','C07CB53','C07CG01','C07DA06','C07DB01','C07FA05','C07FB02','C07FB03','C07FB07')
then 1 else 0 end beta_blocker,
case when Code_calc in (
'C02CA01','C02CA02','C02CA03','C02CA04','C02CA06','C02LE01','C07AG01','C07AG02','C07BG01','C07CG01','G04CA01','G04CA02','G04CA03','G04CA04','G04CA51','G04CA52','G04CA53','R03AA01','R03CA02')
then 1 else 0 end alpha_blocker,
case when Code_calc in (
'C09AA01','C09AA02','C09AA03','C09AA04','C09AA05','C09AA06','C09AA07','C09AA08','C09AA09','C09AA10','C09AA11','C09AA12','C09AA13','C09AA14','C09AA15','C09AA16','C09BA01','C09BA02','C09BA03','C09BA04','C09BA05','C09BA06','C09BA07','C09BA08','C09BA09','C09BA12','C09BA13','C09BA15','C09BB02','C09BB03','C09BB04','C09BB05','C09BB06','C09BB07','C09BB10','C09BB12')
then 1 else 0 end ace_inhibitor,
case when Code_calc in (
'G03CA01','G03CA03','G03CA04','G03CA06','G03CA07','G03CA09','G03CA53','G03CA57','G03CB01','G03CB02','G03CB03','G03CB04','G03CC02','G03CC03','G03CC04','G03CC05','G03CC06','G03CX01')
then 1 else 0 end estrogen,
case when Code_calc in (
'G03DA01','G03DA02','G03DA03','G03DA04','G03DB01','G03DB02','G03DB03','G03DB04','G03DB05','G03DB06','G03DB07','G03DB08','G03DC01','G03DC02','G03DC03','G03DC04','G03DC06','G03DC31')
then 1 else 0 end progestron,
case when Code_calc in (
'G03FA01','G03FA02','G03FA03','G03FA04','G03FA05','G03FA06','G03FA07','G03FA08','G03FA09','G03FA10','G03FA11','G03FA12','G03FA13','G03FA14','G03FA15','G03FA16','G03FA17','G03FB01','G03FB02','G03FB03','G03FB04','G03FB05','G03FB06','G03FB07','G03FB08','G03FB09','G03FB10','G03FB11')
then 1 else 0 end hormone,
case when left(Code_calc,3) in ('H02')
or
left(Code_calc,4) in ('D07A','D07B','D07C','D07X','G01A','G01B','H02A','H02B','S02B','S02C','S03B','S03C')
or
left(Code_calc,5) in ('C05AA','D07AA','D07AB','D07AC','D07AD','D07BA','D07BB','D07BC','D07BD','D07CA','D07CB','D07CC','D07CD','D07XA','D07XB','D07XC','D07XD','G01BC','G01BD','G01BE','G01BF','H02BX','H02CA','M01BA','R01AB','R01AD','S01BA','S01BB','S01CA','S01CB','S02BA','S02CA','S03BA','S03CA')
or
Code_calc in ('M01BA03','D07AB30','D07XB30','M01BA02','M01BA01')
then 1 else 0 end corticosteroids
from lab_vars, Medication
where Medication.Patient_ID=lab_vars.Patient_ID
and
lab_vars.test_date>Medication.StartDate
) med_data
group by Patient_Id

--statin medication
if OBJECT_ID(N'statin_vars', 'U') is not null
begin
	drop table statin_vars
end

select Patient_ID,
max(C10AA_startdate_3m) C10AA_startdate_3m, max(C10AA_stopdate_3m) C10AA_stopdate_3m, max(C10AA_startdate_2y) C10AA_startdate_2y, max(C10AA_stopdate_2y) C10AA_stopdate_2y, max(C10AA_startdate_out_2y) C10AA_startdate_out_2y, max(C10AA_stopdate_out_2y) C10AA_stopdate_out_2y, 
max(C10AB_startdate_3m) C10AB_startdate_3m, max(C10AB_stopdate_3m) C10AB_stopdate_3m, max(C10AB_startdate_2y) C10AB_startdate_2y, max(C10AB_stopdate_2y) C10AB_stopdate_2y, max(C10AB_startdate_out_2y) C10AB_startdate_out_2y, max(C10AB_stopdate_out_2y) C10AB_stopdate_out_2y, 
max(C10AC_startdate_3m) C10AC_startdate_3m, max(C10AC_stopdate_3m) C10AC_stopdate_3m, max(C10AC_startdate_2y) C10AC_startdate_2y, max(C10AC_stopdate_2y) C10AC_stopdate_2y, max(C10AC_startdate_out_2y) C10AC_startdate_out_2y, max(C10AC_stopdate_out_2y) C10AC_stopdate_out_2y, 
max(C10AD_startdate_3m) C10AD_startdate_3m, max(C10AD_stopdate_3m) C10AD_stopdate_3m, max(C10AD_startdate_2y) C10AD_startdate_2y, max(C10AD_stopdate_2y) C10AD_stopdate_2y, max(C10AD_startdate_out_2y) C10AD_startdate_out_2y, max(C10AD_stopdate_out_2y) C10AD_stopdate_out_2y, 
max(C10AX_startdate_3m) C10AX_startdate_3m, max(C10AX_stopdate_3m) C10AX_stopdate_3m, max(C10AX_startdate_2y) C10AX_startdate_2y, max(C10AX_stopdate_2y) C10AX_stopdate_2y, max(C10AX_startdate_out_2y) C10AX_startdate_out_2y, max(C10AX_stopdate_out_2y) C10AX_stopdate_out_2y, 
max(C10BA_startdate_3m) C10BA_startdate_3m, max(C10BA_stopdate_3m) C10BA_stopdate_3m, max(C10BA_startdate_2y) C10BA_startdate_2y, max(C10BA_stopdate_2y) C10BA_stopdate_2y, max(C10BA_startdate_out_2y) C10BA_startdate_out_2y, max(C10BA_stopdate_out_2y) C10BA_stopdate_out_2y, 
max(C10BX_startdate_3m) C10BX_startdate_3m, max(C10BX_stopdate_3m) C10BX_stopdate_3m, max(C10BX_startdate_2y) C10BX_startdate_2y, max(C10BX_stopdate_2y) C10BX_stopdate_2y, max(C10BX_startdate_out_2y) C10BX_startdate_out_2y, max(C10BX_stopdate_out_2y) C10BX_stopdate_out_2y
into statin_vars
from (
select m.Patient_ID,
iif(LEFT(Code_calc,5) in ('C10AA') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10AA_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10AA') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10AA_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10AA') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10AA_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10AA') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AA_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10AA') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10AA_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10AA') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AA_stopdate_out_2y,

iif(LEFT(Code_calc,5) in ('C10AB') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10AB_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10AB') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10AB_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10AB') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10AB_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10AB') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AB_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10AB') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10AB_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10AB') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AB_stopdate_out_2y,

iif(LEFT(Code_calc,5) in ('C10AC') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10AC_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10AC') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10AC_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10AC') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10AC_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10AC') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AC_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10AC') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10AC_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10AC') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AC_stopdate_out_2y,

iif(LEFT(Code_calc,5) in ('C10AD') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10AD_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10AD') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10AD_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10AD') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10AD_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10AD') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AD_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10AD') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10AD_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10AD') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AD_stopdate_out_2y,

iif(LEFT(Code_calc,5) in ('C10AX') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10AX_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10AX') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10AX_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10AX') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10AX_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10AX') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AX_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10AX') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10AX_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10AX') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10AX_stopdate_out_2y,

iif(LEFT(Code_calc,5) in ('C10BA') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10BA_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10BA') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10BA_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10BA') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10BA_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10BA') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10BA_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10BA') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10BA_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10BA') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10BA_stopdate_out_2y,

iif(LEFT(Code_calc,5) in ('C10BX') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.startdate, null) C10BX_startdate_3m,
iif(LEFT(Code_calc,5) in ('C10BX') and m.stopdate_calc>=dateadd(m, -3, l.test_date), m.stopdate_calc, null) C10BX_stopdate_3m,
iif(LEFT(Code_calc,5) in ('C10BX') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.startdate, null) C10BX_startdate_2y,
iif(LEFT(Code_calc,5) in ('C10BX') and m.stopdate_calc<dateadd(m, -3, l.test_date) and m.stopdate_calc>=dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10BX_stopdate_2y,
iif(LEFT(Code_calc,5) in ('C10BX') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.startdate, null) C10BX_startdate_out_2y,
iif(LEFT(Code_calc,5) in ('C10BX') and m.stopdate_calc<dateadd(yy, -2, l.test_date), m.stopdate_calc, null) C10BX_stopdate_out_2y

from
lab_vars l,
(
select Patient_ID, Code_calc, StartDate
, case when StopDate is null or StopDate<=StartDate then dateadd(m, 1, StartDate) else StopDate end stopdate_calc
from Medication
where LEFT(Code_calc,5)  in ('C10AA','C10AB','C10AC','C10AD','C10AX','C10BA','C10BX')
) m
where l.patient_id=m.patient_id
and (m.startdate < l.test_date or m.stopdate_calc < l.test_date)
) statin_data
group by Patient_ID

-- add smoking status, sex, birthyear, postal code
if OBJECT_ID(N'lipid_vars', 'U') is not null
begin
	drop table lipid_vars
end

select lab_vars.patient_id, patient.birthyear, Patient.sex, PatientDemographic.ResidencePostalCode as postalcode
	  ,[test_date]
	  ,[tc]
      ,[tc_date]
      ,[tg]
      ,[tg_date]
      ,[hdl]
      ,[hdl_date]
      ,[ldl]
      ,[ldl_date]      
	  ,[bodyweight]
      ,[bmi]
      ,[height]
      ,[sbp]
      ,[dbp]
      ,[waistcirc]
	  ,iif(risk_vars.Patient_ID is not null, 1, 0) smoking
	  ,iif([diabetes] is null, 0, [diabetes]) [diabetes]
      ,iif([hypertension] is null, 0, [hypertension]) [hypertension] 
      ,iif([dyslipidemia] is null, 0, [dyslipidemia]) [dyslipidemia]
      ,iif([cad] is null, 0, [cad]) [cad]
      ,iif([pad] is null, 0, [pad]) [pad]
      ,iif([aaa] is null, 0, [aaa]) [aaa]
      ,iif([cvd] is null, 0, [cvd]) [cvd]
	  ,iif([thiazides] is null, 0, [thiazides]) [thiazides]
      ,iif([diuretics] is null, 0, [diuretics]) [diuretics]
      ,iif([beta_blocker] is null, 0, [beta_blocker]) [beta_blocker]
      ,iif([alpha_blocker] is null, 0, [alpha_blocker]) [alpha_blocker]
      ,iif([ace_inhibitor] is null, 0, [ace_inhibitor]) [ace_inhibitor]
      ,iif([estrogen] is null, 0, [estrogen]) [estrogen]
      ,iif([progestron] is null, 0, [progestron]) [progestron]
      ,iif([hormone] is null, 0, [hormone]) [hormone]
      ,iif([corticosteroids] is null, 0, [corticosteroids]) [corticosteroids]
      ,[C10AA_startdate_3m]
      ,[C10AA_stopdate_3m]
      ,[C10AA_startdate_2y]
      ,[C10AA_stopdate_2y]
      ,[C10AA_startdate_out_2y]
      ,[C10AA_stopdate_out_2y]
      ,[C10AB_startdate_3m]
      ,[C10AB_stopdate_3m]
      ,[C10AB_startdate_2y]
      ,[C10AB_stopdate_2y]
      ,[C10AB_startdate_out_2y]
      ,[C10AB_stopdate_out_2y]
      ,[C10AC_startdate_3m]
      ,[C10AC_stopdate_3m]
      ,[C10AC_startdate_2y]
      ,[C10AC_stopdate_2y]
      ,[C10AC_startdate_out_2y]
      ,[C10AC_stopdate_out_2y]
      ,[C10AD_startdate_3m]
      ,[C10AD_stopdate_3m]
      ,[C10AD_startdate_2y]
      ,[C10AD_stopdate_2y]
      ,[C10AD_startdate_out_2y]
      ,[C10AD_stopdate_out_2y]
      ,[C10AX_startdate_3m]
      ,[C10AX_stopdate_3m]
      ,[C10AX_startdate_2y]
      ,[C10AX_stopdate_2y]
      ,[C10AX_startdate_out_2y]
      ,[C10AX_stopdate_out_2y]
      ,[C10BA_startdate_3m]
      ,[C10BA_stopdate_3m]
      ,[C10BA_startdate_2y]
      ,[C10BA_stopdate_2y]
      ,[C10BA_startdate_out_2y]
      ,[C10BA_stopdate_out_2y]
      ,[C10BX_startdate_3m]
      ,[C10BX_stopdate_3m]
      ,[C10BX_startdate_2y]
      ,[C10BX_stopdate_2y]
      ,[C10BX_startdate_out_2y]
      ,[C10BX_stopdate_out_2y]
into lipid_vars
from lab_vars
inner join patient on lab_vars.Patient_ID=patient.Patient_ID
inner join PatientDemographic on lab_vars.Patient_ID=PatientDemographic.Patient_ID
left join (select patient_id from riskfactor where Name_calc='Smoking' and Status_orig in ('Past','Current') group by patient_id) risk_vars on lab_vars.Patient_ID=risk_vars.Patient_ID
left join exam_vars on lab_vars.Patient_ID=exam_vars.Patient_ID
left join condition_vars on lab_vars.Patient_ID=condition_vars.Patient_ID
left join med_vars on lab_vars.Patient_ID=med_vars.Patient_ID
left join statin_vars on lab_vars.Patient_ID=statin_vars.Patient_ID

