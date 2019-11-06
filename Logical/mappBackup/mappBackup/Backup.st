// ----------------------------------------------------------------------------------------
//	Function:	Mini explorer																			
//  Version:	1.00																					
//	Changed:	04.11.2019																				
//	Error numbers:																						
//	50000		Backup name is empty																
//	50001		Device name is empty																
// ----------------------------------------------------------------------------------------

PROGRAM _INIT
	// ----------------------------------------------------------------------------------------
	brsmemcpy(ADR(Backup_01.PAR.DeviceList), ADR(BACKUP_DEVICE_LIST), SIZEOF(BACKUP_DEVICE_LIST));
	
END_PROGRAM

PROGRAM _CYCLIC

	// ------------------------------------------------------------------------------------------------
	// Generate device name list
	brsmemset(ADR(Backup_01.VIS.DeviceList), 0, SIZEOF(Backup_01.VIS.DeviceList));
	FOR idx := 0 TO SIZEOF(Backup_01.VIS.DeviceList)/SIZEOF(Backup_01.VIS.DeviceList[0]) - 1 DO 
		IF (Backup_01.PAR.DeviceList[idx] <> '') THEN
			String2DataProvider(ADR(Backup_01.PAR.DeviceList[idx]), ADR(Backup_01.VIS.DeviceList[idx]));
		END_IF
	END_FOR;

	//**************************************************************************************************
	// Backup managment state machine																						
	//**************************************************************************************************	
	CASE bac_state OF
		//**********************************************************************************************
		// Wait for command																				
		//**********************************************************************************************
		BAC_WAIT:
			Backup_01.DAT.Status := "Waiting...";
			
			// ---------------------------------------------------------------------------------------- 
			// Make sure backup name is not empty
			IF ((Backup_01.CMD.Backup = TRUE OR Backup_01.CMD.Restore = TRUE) AND Backup_01.PAR.BackupName <> '') THEN
				bac_state := CreateError(ADR(Backup_01), ERR_BAC_NAME_IS_EMPTY, "Backup name is empty", bac_state);
				RETURN;
			END_IF
			
			// ---------------------------------------------------------------------------------------- 
			// Make sure device name is not empty
			IF ((Backup_01.CMD.Backup = TRUE OR Backup_01.CMD.Restore = TRUE) AND Backup_01.PAR.BackupName <> '') THEN
				bac_state := CreateError(ADR(Backup_01), ERR_BAC_DEVICE_IS_EMPTY, "Device name is empty", bac_state);
				RETURN;
			END_IF
			
			// ---------------------------------------------------------------------------------------- 
			// Command load recipe
			IF (Backup_01.CMD.Backup = TRUE AND Backup_01.PAR.BackupName <> '') THEN
				// Show current state
				tmpWStr := "creating backup...";
				bac_state := BAC_CORE;
			END_IF
			
			// ---------------------------------------------------------------------------------------- 
			// Command refresh information
			IF (Backup_01.CMD.RefreshInfo = TRUE) THEN
				// Show current state
				tmpWStr := "refreshing information...";
				bac_state := BAC_CORE;
			END_IF
			
			// ---------------------------------------------------------------------------------------- 
			// Command load recipe
			IF (Backup_01.CMD.GenerateName = TRUE) THEN
				// Generate backup name
				bac_state := BAC_GENERATE_NAME;
			END_IF
			
			MpBackupCore_0.ErrorReset := FALSE;
		//**********************************************************************************************
		// Generate backup name																				
		//**********************************************************************************************
		BAC_GENERATE_NAME:
			Backup_01.PAR.BackupName := Backup_01.PAR.DefaultName;
			RTC_gettime(ADR(rtc_gettime)); 
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_D'));
			IF(rtc_gettime.day < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.day, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr));
			brsitoa(rtc_gettime.day, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_M'));
			IF(rtc_gettime.month < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.month, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_Y'));
			brsitoa(rtc_gettime.year, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_h'));
			IF(rtc_gettime.hour < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.hour, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_m'));
			IF(rtc_gettime.minute < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.minute, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_s'));
			IF(rtc_gettime.second < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.second, ADR(tmpStr));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr));

			Backup_01.CMD.GenerateName := FALSE;
			bac_state := BAC_WAIT;
		// --------------------------------------------------------------------------------------------------------------------
		// Core function call 
		// --------------------------------------------------------------------------------------------------------------------					
		BAC_CORE:
			// ------------------------------------------------------------------------------------------------
			// Main backup function call
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr), animation);

			// ---------------------------------------------------------------------------------------- 		
			// OK																																				
			IF (MpBackupCore_0.CommandDone AND NOT MpBackupCore_0.Error) THEN
				brsmemset(ADR(Backup_01.CMD), 0, SIZEOF(Backup_01.CMD));
				bac_state := BAC_WAIT;
			// Error
			ELSIF (MpBackupCore_0.Error) THEN
				IF (Backup_01.CMD.Backup) THEN					
					tmpWStr := "error trying to backup data";
				ELSIF (Backup_01.CMD.Restore) THEN
					tmpWStr := "error trying to restore data";
				ELSIF (Backup_01.CMD.RefreshInfo) THEN
					IF(MpBackupCore_0.StatusID =  mpBACKUP_ERR_REQUEST_INFO_FAILED) THEN
						tmpWStr := "backup name was not found";
					ELSE
						tmpWStr := "error trying to refresh backup information";
					END_IF
				END_IF
				bac_state := CreateError(ADR(Backup_01), MpBackupCore_0.StatusID, tmpWStr, bac_state);
			END_IF				
			// --------------------------------------------------------------------------------------------------------------------
		// Error 
		// --------------------------------------------------------------------------------------------------------------------					
		BAC_ERROR:
			Backup_01.DAT.Status := "error state triggered";
			// --------------------------------------------------------------------------------------------------------------------	
			// Return to idle state
			IF (Backup_01.CMD.ErrorReset) THEN
				// Reset function blocks
				MpBackupCore_0.ErrorReset := TRUE;
				
				// Reset error structure
				brsmemset(ADR(Backup_01.ERR), 0, SIZEOF(Backup_01.ERR));
				Backup_01.DAT.Status := "";
				Backup_01.VIS.ShowMessageBoxError := FALSE;
				bac_state := BAC_WAIT;
			END_IF;	
			brsmemset(ADR(Backup_01.CMD), 0, SIZEOF(Backup_01.CMD));
	END_CASE
	
	// --------------------------------------------------------------------------------------------------------------------
	// Cyclic function calls
	MpBackupCore_0.Enable := 1;
	MpBackupCore_0.MpLink := ADR(gBackupCore);
	MpBackupCore_0.Name := ADR(Backup_01.PAR.BackupName);
	MpBackupCore_0.DeviceName := ADR(Backup_01.PAR.DeviceName);
	MpBackupCore_0.Create := Backup_01.CMD.Backup;
	MpBackupCore_0.Install := Backup_01.CMD.Restore;
	MpBackupCore_0.RequestInfo := Backup_01.CMD.RefreshInfo;
	MpBackupCore_0();
	
	Backup_01.DAT.CurrentID := MpBackupCore_0.Info.Project.Current.ConfigurationID;
	Backup_01.DAT.CurrentVersion := MpBackupCore_0.Info.Project.Current.ConfigurationVersion;
	Backup_01.DAT.RequestedName := MpBackupCore_0.Info.Project.Requested.Name;
	Backup_01.DAT.RequestedID := MpBackupCore_0.Info.Project.Requested.ConfigurationID;
	Backup_01.DAT.RequestedVersion := MpBackupCore_0.Info.Project.Requested.ConfigurationVersion;
	Backup_01.DAT.LastName := MpBackupCore_0.Info.LastBackup.Name;
	Backup_01.DAT.LastDate := MpBackupCore_0.Info.LastBackup.DateTime;
	Backup_01.DAT.LastType := MpBackupCore_0.Info.LastBackup.GenerationType;
END_PROGRAM

PROGRAM _EXIT
	MpBackupCore_0.Enable := 0;
	MpBackupCore_0();
END_PROGRAM
