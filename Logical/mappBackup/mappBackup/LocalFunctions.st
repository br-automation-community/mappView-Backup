//******************************************************************************************************
// Create mappView data provider string
//******************************************************************************************************
FUNCTION String2DataProvider
	brsstrcpy(TargetString, ADR('{"value":"'));
	brsstrcat(TargetString, SourceString);
	brsstrcat(TargetString, ADR('","text":"'));	
	brsstrcat(TargetString, SourceString);
	brsstrcat(TargetString, ADR('"}'));
	String2DataProvider := TRUE;
END_FUNCTION

//******************************************************************************************************
// Create error																						
//******************************************************************************************************
FUNCTION CreateError
	BACKUP.ERR.No := No;
	BACKUP.ERR.State := State;
	BACKUP.ERR.Text := Text;
	CreateError := BAC_ERROR;
END_FUNCTION

//******************************************************************************************************
// Working status																						
//******************************************************************************************************
FUNCTION WorkingStatus
	animation := animation+1;
	
	// Get one second counter
	counter := animation;
	WHILE counter >= 100 DO
		counter := counter - 100;
	END_WHILE;
	
	IF (counter = 99) THEN
		counter := 0;
	END_IF
	
	// Add counter to output string
	brsmemset(ADR(BACKUP.DAT.Status), 0, SIZEOF(BACKUP.DAT.Status));
	brwcscpy(ADR(BACKUP.DAT.Status), str);
	brwcscat(ADR(BACKUP.DAT.Status), ADR(" "));
	brsitoa(animation/100, ADR(tmpStr));
	brwcsconv(ADR(tmpWStr), ADR(tmpStr), brwU8toUC);
	brwcscat(ADR(BACKUP.DAT.Status), ADR(tmpWStr));
	brwcscat(ADR(BACKUP.DAT.Status), ADR("s "));
	
	// Add rotating element to output string
	CASE(counter) OF
		0..24	: brwcscat(ADR(BACKUP.DAT.Status), ADR("/"));
		25..49	: brwcscat(ADR(BACKUP.DAT.Status), ADR("-"));
		50..74	: brwcscat(ADR(BACKUP.DAT.Status), ADR("\"));
		75..99	: brwcscat(ADR(BACKUP.DAT.Status), ADR("|"));
	END_CASE;
	WorkingStatus := animation;
END_FUNCTION

//******************************************************************************************************
// Fill in new directory name																	
//******************************************************************************************************
FUNCTION InsertRecName
	// Set up start values for iteration																
	IF (BAC.DAT.BackupNum <> 0) THEN 
		idy := BAC.DAT.BackupNum - 1;
	END_IF
	idx := idy;
	
	// Start iteration	search																			
	WHILE (idy > 1) DO
		// Check current entry																			
		lSort := brsstrcmp(ADR(new_name), ADR(BAC.DAT.BackupNames[idy]));
		// Solve new search range																		
		IF (idy MOD 2 = 0) THEN
			idy := idy / 2;
		ELSE				
			idy := idy / 2 + 1;
		END_IF
		// New range is lower or higher than current													
		IF (lSort > 0) THEN
			idx := idx + idy;
			IF (idx > UINT_TO_INT(BAC.DAT.BackupNum)) THEN
				idx := BAC.DAT.BackupNum;  
			END_IF
		ELSE
			idx := idx - idy;
			IF (idx < 1) THEN
				idx := 1;
			END_IF
		END_IF		
	END_WHILE;
			
	// New entry is this, next or previous 																
	lSort := brsstrcmp(ADR(new_name), ADR(BAC.DAT.BackupNames[idx]));
	IF (lSort > 0 AND idx <> UINT_TO_INT(BAC.DAT.BackupNum)) THEN 
		idx := idx +1;
	ELSIF (idx > 0) THEN
		lSort := brsstrcmp(ADR(new_name), ADR(BAC.DAT.BackupNames[idx-1]));
		IF (lSort < 0) THEN 
			idx := idx - 1;
		END_IF
	END_IF
	
	// Move all data entrys backwards and fill in new entry
	IF(idx < BACKUP_LIST_NUM) THEN
		brsmemmove(ADR(BAC.DAT.BackupNames[idx+1]),ADR(BAC.DAT.BackupNames[idx]), (BAC.DAT.BackupNum - idx) * SIZEOF(BAC.DAT.BackupNames[0]));
	END_IF
	brsstrcpy(ADR(BAC.DAT.BackupNames[idx]), ADR(new_name));
	BAC.DAT.BackupNum := BAC.DAT.BackupNum + 1;
	
	InsertRecName := TRUE;
END_FUNCTION