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
	
	IF (animation = 80) THEN
		animation := 0;
	END_IF
	
	brsmemset(ADR(BACKUP.DAT.Status), 0, SIZEOF(BACKUP.DAT.Status));
	brwcscpy(ADR(BACKUP.DAT.Status), str);
	CASE(animation) OF
		0..19	: brwcscat(ADR(BACKUP.DAT.Status), ADR("/"));
		20..39	: brwcscat(ADR(BACKUP.DAT.Status), ADR("-"));
		40..59	: brwcscat(ADR(BACKUP.DAT.Status), ADR("\"));
		60..79	: brwcscat(ADR(BACKUP.DAT.Status), ADR("|"));
	END_CASE;
	WorkingStatus := animation;
END_FUNCTION