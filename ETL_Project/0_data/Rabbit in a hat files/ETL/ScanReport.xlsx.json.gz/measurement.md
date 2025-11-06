## Table name: measurement

### Reading from 0_coadread_tcga_pan_can_atlas_2018_clinical_data.tsv

![](md_files/image3.png)

| Destination Field | Source field | Logic | Comment field |
| --- | --- | --- | --- |
| measurement_id |  |  |  |
| person_id |  |  |  |
| measurement_concept_id | aneuploidy score<br>buffa hypoxia score<br>fraction genome altered<br>ragnum hypoxia score<br>msi mantis score<br>msisensor score<br>mutation count | measurement_concept_id = 0<br>measurement_concept_id = 0<br>measurement_concept_id = 0<br>measurement_concept_id = 0<br>measurement_concept_id = 0<br><br>measurement_concept_id = 0 |  |
| measurement_date | aneuploidy score<br>buffa hypoxia score<br>fraction genome altered<br>ragnum hypoxia score<br>msi mantis score<br>msisensor score<br>mutation count | measurement_date = diagnosis_anchor   diagnosis_anchor = DATE '2000-01-01'.<br>measurement_date = diagnosis_anchor  diagnosis_anchor = DATE '2000-01-01'.<br>measurement_date = diagnosis_anchor<br>measurement_date = diagnosis_anchor  diagnosis_anchor = DATE '2000-01-01'.<br>measurement_date = diagnosis_anchor  diagnosis_anchor = DATE '2000-01-01'.<br>measurement_date = diagnosis_anchor   diagnosis_anchor = DATE '2000-01-01'.<br>measurement_date = diagnosis_anchor |  |
| measurement_datetime |  |  |  |
| measurement_time |  |  |  |
| measurement_type_concept_id |  |  |  |
| operator_concept_id |  |  |  |
| value_as_number | aneuploidy score<br>buffa hypoxia score<br>fraction genome altered<br>ragnum hypoxia score<br>msi mantis score<br>msisensor score<br>mutation count | value_as_number = CAST([Aneuploidy Score] AS NUMERIC)<br>value_as_number = CAST([Fraction Genome Altered] AS NUMERIC)<br>value_as_number = CAST([Fraction Genome Altered] AS NUMERIC)<br>value_as_number = CAST([Ragnum Hypoxia Score] AS NUMERIC)<br>value_as_number = CAST([MSI Mantis Score] AS NUMERIC)<br>value_as_number = CAST([MSIsensor Score] AS NUMERIC)<br>value_as_number = CAST([Mutation Count] AS NUMERIC |  |
| value_as_concept_id |  |  |  |
| unit_concept_id |  |  |  |
| range_low |  |  |  |
| range_high |  |  |  |
| provider_id |  |  |  |
| visit_occurrence_id |  |  |  |
| visit_detail_id |  |  |  |
| measurement_source_value | aneuploidy score<br>buffa hypoxia score<br>fraction genome altered<br>ragnum hypoxia score<br>msi mantis score<br>msisensor score<br>mutation count | measurement_source_value = 'Aneuploidy Score'<br>measurement_source_value = 'Buffa Hypoxia Score'<br>value_as_number = CAST([Fraction Genome Altered] AS NUMERIC)<br>measurement_source_value = 'Ragnum Hypoxia Score'<br>measurement_source_value = 'MSI mantis Score'<br>measurement_source_value = 'MSIsensor Score'<br>measurement_source_value = 'Mutation Count' |  |
| measurement_source_concept_id |  |  |  |
| unit_source_value |  |  |  |
| unit_source_concept_id |  |  |  |
| value_source_value |  |  |  |
| measurement_event_id |  |  |  |
| meas_event_field_concept_id |  |  |  |

