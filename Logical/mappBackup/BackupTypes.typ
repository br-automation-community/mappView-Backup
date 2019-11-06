(*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*)
(*Global enumerations*)

TYPE
	bacSTATE : 
		( (*Recipe managment state machine*)
		BAC_WAIT,
		BAC_CORE,
		BAC_GENERATE_NAME,
		BAC_ERROR
		);
END_TYPE

(*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*)
(*Global structure*)

TYPE
	bacMAIN : 	STRUCT  (*Recipe managment main structure*)
		CMD : bacCMD; (* Command structure *)
		PAR : bacPAR; (* Parameter structure *)
		DAT : bacDAT; (*Data structure*)
		VIS : bacVIS; (*Visualization structure*)
		ERR : bacERR; (* Error structure *)
	END_STRUCT;
	bacCMD : 	STRUCT  (*Recipe managment command structure*)
		Backup : BOOL;
		Restore : BOOL;
		GenerateName : BOOL;
		RefreshInfo : BOOL;
		ErrorReset : BOOL;
	END_STRUCT;
	bacPAR : 	STRUCT  (*Recipe managment parameter structure*)
		BackupName : STRING[100] := 'MyBackup'; (*Name of the variable where the data is stored*)
		DefaultName : STRING[100] := 'MyBackup'; (*Name of the variable where the data is stored*)
		DeviceName : STRING[100] := 'USB_DEVICE'; (*Device name where the bacipes are stored*)
		DeviceList : ARRAY[0..4]OF STRING[40]; (*List of all devices*)
		VisuSlotID : USINT; (*ID for connected web connection*)
	END_STRUCT;
	bacDAT : 	STRUCT  (*Recipe managment data structure*)
		CurrentID : STRING[255];
		CurrentVersion : STRING[64];
		RequestedName : STRING[255];
		RequestedID : STRING[255];
		RequestedVersion : STRING[64];
		LastName : STRING[255];
		LastDate : DATE_AND_TIME;
		LastType : MpBackupGenerationTypeEnum;
		Status : WSTRING[100]; (*Shows the result of the last command*)
	END_STRUCT;
	bacVIS : 	STRUCT  (*Recipe managment visualization structure*)
		DeviceList : ARRAY[0..4]OF STRING[80]; (* Device name *)
		ShowMessageBoxError : BOOL; (*Show message box on error*)
		EnableCommand : BOOL;
	END_STRUCT;
	bacERR : 	STRUCT  (*Recipe managment error structure*)
		Text : WSTRING[200]; (* Error text *)
		No : DINT; (* Error number *)
		State : bacSTATE; (* Error step *)
	END_STRUCT;
END_TYPE
