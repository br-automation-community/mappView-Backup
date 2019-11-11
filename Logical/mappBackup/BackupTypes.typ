(*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*)
(*Global enumerations*)

TYPE
	bacSTATE : 
		( (*Backup managment state machine*)
		BAC_STARTUP,
		BAC_WAIT,
		BAC_CORE,
		BAC_FINISH,
		BAC_GENERATE_NAME,
		BAC_READ_DIR_0,
		BAC_READ_DIR_1,
		BAC_READ_DIR_2,
		BAC_READ_DIR_3,
		BAC_READ_DIR_4,
		BAC_DIR_DELETE,
		BAC_DIR_CREATE,
		BAC_ERROR
		);
END_TYPE

(*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*)
(*Global structure*)

TYPE
	bacMAIN : 	STRUCT  (*Backup managment main structure*)
		CMD : bacCMD; (* Command structure *)
		PAR : bacPAR; (* Parameter structure *)
		DAT : bacDAT; (*Data structure*)
		VIS : bacVIS; (*Visualization structure*)
		ERR : bacERR; (* Error structure *)
	END_STRUCT;
	bacCMD : 	STRUCT  (*Backup managment command structure*)
		Backup : BOOL; (*Create a new backup*)
		Restore : BOOL; (*Restore selected backup*)
		Delete : BOOL; (*Delete the selected backaup*)
		GenerateName : BOOL; (*Generate backup name from default name and date*)
		RefreshInfo : BOOL; (*Refresh information for selected backup*)
		RefreshDirectory : BOOL; (*Refresh backup directory names*)
		ErrorReset : BOOL; (*Reset pending errors*)
	END_STRUCT;
	bacPAR : 	STRUCT  (*Backup managment parameter structure*)
		BackupName : STRING[BACKUP_NAME_LENGTH] := 'MyBackup'; (*Name of the variable where the data is stored*)
		DefaultName : STRING[BACKUP_NAME_LENGTH] := 'MyBackup'; (*Name of the variable where the data is stored*)
		DeviceName : STRING[BACKUP_NAME_LENGTH] := 'USB_DEVICE'; (*Device name where the bacipes are stored*)
		UniqueName : STRING[BACKUP_NAME_LENGTH] := 'RestoreInProcessPLC1'; (*Unique name for this PLC to identify if restore was completed*)
		DeviceList : ARRAY[0..4]OF STRING[40]; (*List of all devices*)
		VisuSlotID : USINT; (*ID for connected web connection*)
		ShowMessageBoxOK : BOOL := TRUE;
		ShowMessageBoxError : BOOL := TRUE;
		MpLink : MpComIdentType; (*MpLink from mappBackup*)
	END_STRUCT;
	bacDAT : 	STRUCT  (*Backup managment data structure*)
		CurrentID : STRING[255];
		CurrentVersion : STRING[64];
		RequestedName : STRING[255];
		RequestedID : STRING[255];
		RequestedVersion : STRING[64];
		LastName : STRING[255];
		LastDate : DATE_AND_TIME;
		LastType : MpBackupGenerationTypeEnum;
		BackupNames : ARRAY[0..BACKUP_LIST_NUM]OF STRING[BACKUP_NAME_LENGTH];
		BackupNum : USINT;
		Status : WSTRING[200]; (*Shows the result of the last command*)
	END_STRUCT;
	bacVIS : 	STRUCT  (*Backup managment visualization structure*)
		DeviceList : ARRAY[0..4]OF STRING[80]; (* Device name *)
		BackupNames : ARRAY[0..BACKUP_LIST_NUM]OF STRING[BACKUP_VIS_LENGTH];
		EnableCommand : BOOL;
		EnableDelete : BOOL;
		ShowMessageBoxOK : BOOL;
		ShowMessageBoxError : BOOL;
	END_STRUCT;
	bacERR : 	STRUCT  (*Backup managment error structure*)
		Text : WSTRING[200]; (* Error text *)
		No : DINT; (* Error number *)
		State : bacSTATE; (* Error step *)
	END_STRUCT;
END_TYPE
