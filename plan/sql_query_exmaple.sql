SELECT
  count(1) as 'Count',
  (SELECT count(1) as 'Count' from BUCKET group by cut) as 'Cuts'
FRO diamonds group by 1
