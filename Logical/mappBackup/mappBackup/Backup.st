// ----------------------------------------------------------------------------------------
//	Function:	Software management for B&R PLCs																			
//  Version:	0.1																					
//	Changed:	11.11.2019																				
//	Error numbers:																						
//	50000		Backup name is empty																
//	50001		Device name is empty																
//	50010		Maximum number of backup names reached																
//	50011		Backup name length exceeds maximum size																
//	50020		Backup name already exists															
// ----------------------------------------------------------------------------------------

PROGRAM _INIT
	// ----------------------------------------------------------------------------------------
	Backup_01.PAR.MpLink := gBackupCore;				// Link to mappBackup configuration

	// ----------------------------------------------------------------------------------------
	brsmemcpy(ADR(Backup_01.PAR.DeviceList), ADR(BACKUP_DEVICE_LIST), SIZEOF(BACKUP_DEVICE_LIST));
	Backup_01.DAT.Status := "Waiting...";

	MpBackupCore_0.MpLink := ADR(Backup_01.PAR.MpLink);
	MpBackupCore_0.Name := ADR(BackupName);
	MpBackupCore_0.DeviceName := ADR(DeviceName);
	
END_PROGRAM

PROGRAM _CYCLIC
	// --------------------------------------------------------------------------------------------------------------------
	// Cyclic function call
	MpBackupCore_0.Enable := 1;
	MpBackupCore_0();
	
	// ------------------------------------------------------------------------------------------------
	// Generate device name list
	brsmemset(ADR(Backup_01.VIS.DeviceList), 0, SIZEOF(Backup_01.VIS.DeviceList));
	FOR idx := 0 TO SIZEOF(Backup_01.VIS.DeviceList)/SIZEOF(Backup_01.VIS.DeviceList[0]) - 1 DO 
		IF (Backup_01.PAR.DeviceList[idx] <> '') THEN
			String2DataProvider(ADR(Backup_01.PAR.DeviceList[idx]), ADR(Backup_01.VIS.DeviceList[idx]));
		END_IF
	END_FOR;
	
	// ------------------------------------------------------------------------------------------------
	// Generate backup name list
	brsmemset(ADR(Backup_01.VIS.BackupNames), 0, SIZEOF(Backup_01.VIS.BackupNames));
	IF(Backup_01.DAT.BackupNum > 0) THEN
		FOR idx := 0 TO Backup_01.DAT.BackupNum - 1 DO 
			IF (Backup_01.DAT.BackupNames[idx] <> '') THEN
				String2DataProvider(ADR(Backup_01.DAT.BackupNames[idx]), ADR(Backup_01.VIS.BackupNames[idx]));
			END_IF
		END_FOR;
	END_IF
		
	// ------------------------------------------------------------------------------------------------
	// Enable/Disable visualization elements
	IF(bac_state <> BAC_WAIT) THEN
		Backup_01.VIS.EnableCommand := FALSE;
	ELSE
		Backup_01.VIS.EnableCommand := TRUE;
	END_IF
	IF(Backup_01.DAT.BackupNum = 0) THEN
		Backup_01.VIS.EnableDelete := FALSE;
	ELSE
		Backup_01.VIS.EnableDelete := TRUE;
	END_IF

	//**************************************************************************************************
	// Backup managment state machine																						
	//**************************************************************************************************	
	CASE bac_state OF
		//**********************************************************************************************
		// Wait for USB and network connection to startup																				
		//**********************************************************************************************
		BAC_STARTUP:
			Backup_01.DAT.Status := "Waiting for USB and network connections to startup";
			StartupDelay(IN := 1, PT := DELAY_STARTUP);
			IF (StartupDelay.Q) THEN
				bac_state := BAC_WAIT;
			END_IF	
		//**********************************************************************************************
		// Wait for command																				
		//**********************************************************************************************
		BAC_WAIT:			
			// ---------------------------------------------------------------------------------------- 
			// Make sure device name is not empty
			IF ((Backup_01.CMD.Backup = TRUE OR Backup_01.CMD.Restore = TRUE OR Backup_01.CMD.Delete = TRUE OR Backup_01.CMD.RefreshDirectory = TRUE OR Backup_01.CMD.RefreshInfo = TRUE) AND Backup_01.PAR.DeviceName = '') THEN
				bac_state := CreateError(ADR(Backup_01), ERR_BAC_NAME_IS_EMPTY, "Device name is empty", bac_state);
				RETURN;
			ELSE
				// Freeze device name
				DeviceName := Backup_01.PAR.DeviceName;
			END_IF
			
			// ---------------------------------------------------------------------------------------- 
			// Make sure backup name is not empty
			IF ((Backup_01.CMD.Backup = TRUE OR Backup_01.CMD.Restore = TRUE OR Backup_01.CMD.Delete = TRUE OR Backup_01.CMD.RefreshInfo = TRUE) AND Backup_01.PAR.BackupName = '') THEN
				bac_state := CreateError(ADR(Backup_01), ERR_BAC_DEVICE_IS_EMPTY, "Backup name is empty", bac_state);
				RETURN;
			ELSE
				// Freeze backup name
				BackupName := Backup_01.PAR.BackupName;
			END_IF
			
			// ------------------------------------------------------------------------------------------------
			// Track device name change
			IF (brsstrcmp(ADR(DeviceNameOld), ADR(DeviceName)) <> 0) THEN
				Backup_01.CMD.RefreshDirectory	:= 1;
			END_IF
			DeviceNameOld := DeviceName;
			
			// ---------------------------------------------------------------------------------------- 
			// Command restore backup
			IF (Backup_01.CMD.Restore = TRUE) THEN
				// Show current state
				tmpWStr1 := "Restoring backup...";
				bac_state := BAC_DIR_CREATE;
			// ---------------------------------------------------------------------------------------- 
			// Command create backup
			ELSIF (Backup_01.CMD.Backup = TRUE) THEN
				// Make sure that backup name does not already exist
				IF(Backup_01.DAT.BackupNum > 0) THEN
					FOR idx:=0 TO Backup_01.DAT.BackupNum - 1 DO
						IF(brsstrcmp(ADR(BackupName), ADR(Backup_01.DAT.BackupNames[idx])) = 0) THEN
							bac_state := CreateError(ADR(Backup_01), ERR_BAC_NAME_EXISTS, "Backup name already exists", bac_state);
							RETURN;
						END_IF
					END_FOR;
				END_IF

				// Show current state
				tmpWStr1 := "Creating backup...";
				bac_state := BAC_CORE;
			// ---------------------------------------------------------------------------------------- 
			// Command delete backup
			ELSIF (Backup_01.CMD.Delete = TRUE) THEN
				// Show current state
				tmpWStr1 := "Deleting backup...";
				bac_state := BAC_DIR_DELETE;					
			// ---------------------------------------------------------------------------------------- 
			// Command refresh backup information
			ELSIF (Backup_01.CMD.RefreshInfo = TRUE) THEN
				// Show current state
				tmpWStr1 := "Refreshing backup information...";
				bac_state := BAC_CORE;
			// ---------------------------------------------------------------------------------------- 
			// Command refresh device information
			ELSIF (Backup_01.CMD.RefreshDirectory = TRUE) THEN
				// Show current state
				tmpWStr1 := "Refreshing direct ory information...";
				DeviceIdx := 0;
				found_restore_dir := FALSE;
				DeviceName := Backup_01.PAR.DeviceName;
				bac_state := BAC_READ_DIR_0;				
			// ---------------------------------------------------------------------------------------- 
			// Command generate backup name
			ELSIF (Backup_01.CMD.GenerateName = TRUE) THEN
				// Generate backup name
				bac_state := BAC_GENERATE_NAME;
			// ---------------------------------------------------------------------------------------- 
			// Command reset error
			ELSIF (Backup_01.CMD.ErrorReset = TRUE) THEN
				// Generate backup name
				bac_state := BAC_ERROR;
			END_IF
			
			animation := 0;
			MpBackupCore_0.ErrorReset := FALSE;
		//**********************************************************************************************
		// Generate backup name																				
		//**********************************************************************************************
		BAC_GENERATE_NAME:
			// Generate backup name using default name and date
			Backup_01.PAR.BackupName := Backup_01.PAR.DefaultName;
			RTC_gettime(ADR(rtc_gettime)); 
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_D'));
			IF(rtc_gettime.day < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.day, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr1));
			brsitoa(rtc_gettime.day, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_M'));
			IF(rtc_gettime.month < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.month, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_Y'));
			brsitoa(rtc_gettime.year, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_h'));
			IF(rtc_gettime.hour < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.hour, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_m'));
			IF(rtc_gettime.minute < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.minute, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('_s'));
			IF(rtc_gettime.second < 10) THEN
				brsstrcat(ADR(Backup_01.PAR.BackupName), ADR('0'));
			END_IF
			brsitoa(rtc_gettime.second, ADR(tmpStr1));
			brsstrcat(ADR(Backup_01.PAR.BackupName), ADR(tmpStr1));

			Backup_01.CMD.GenerateName := FALSE;
			bac_state := BAC_WAIT;
		// --------------------------------------------------------------------------------------------------------------------
		// Core function call 
		// --------------------------------------------------------------------------------------------------------------------					
		BAC_CORE:
			// ------------------------------------------------------------------------------------------------
			// Main backup function call
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr1), animation);

			// ---------------------------------------------------------------------------------------- 		
			// OK																																				
			IF (MpBackupCore_0.CommandDone AND NOT MpBackupCore_0.Error) THEN
				IF(Backup_01.CMD.RefreshInfo OR Backup_01.CMD.Restore) THEN
					bac_state := BAC_FINISH;
				ELSE
					bac_state := BAC_READ_DIR_0;
				END_IF
				// ---------------------------------------------------------------------------------------- 		
			// Error
			ELSIF (MpBackupCore_0.Error) THEN
				// ---------------------------------------------------------------------------------------- 		
				// Generate error message depending on initial command
				IF (Backup_01.CMD.Backup) THEN					
					IF(MpBackupCore_0.StatusID =  mpBACKUP_ERR_CREATE_FAILED) THEN
						tmpWStr1 := "Backup name already exists";
					ELSE
						tmpWStr1 := "Error trying to backup data";
					END_IF
				ELSIF (Backup_01.CMD.Restore) THEN 
					IF(MpBackupCore_0.StatusID =  mpBACKUP_ERR_INSTALL_FAILED) THEN
						tmpWStr1 := "Can not find backup name";
					ELSE
						tmpWStr1 := "Error trying to restore data";
					END_IF
				ELSIF (Backup_01.CMD.RefreshInfo) THEN
					IF(MpBackupCore_0.StatusID =  mpBACKUP_ERR_REQUEST_INFO_FAILED) THEN
						bac_state := BAC_FINISH;
						RETURN;
					ELSE
						tmpWStr1 := "Error trying to refresh backup information";
					END_IF
				END_IF
				bac_state := CreateError(ADR(Backup_01), MpBackupCore_0.StatusID, tmpWStr1, bac_state);
			END_IF
		//**********************************************************************************************
		// Finish command																	
		//**********************************************************************************************
		BAC_FINISH:
			// ---------------------------------------------------------------------------------------- 		
			// Comand backup
			IF (Backup_01.CMD.Backup) THEN
				// Reset command, set status and show message box
				Backup_01.DAT.Status := "Backup completed";
				IF(Backup_01.PAR.ShowMessageBoxOK) THEN
					Backup_01.VIS.ShowMessageBoxOK := TRUE;
				END_IF
			// ---------------------------------------------------------------------------------------- 		
			// Comand restore
			ELSIF (Backup_01.CMD.Restore) THEN
				// Reset command, set status, return to wait state
				Backup_01.DAT.Status := "Restore backup completed";
			// ---------------------------------------------------------------------------------------- 		
			// Comand delete
			ELSIF (Backup_01.CMD.Delete) THEN
				// Reset command, set status, return to wait state
				Backup_01.DAT.Status := "Deleted backup";
				IF(Backup_01.PAR.ShowMessageBoxOK) THEN
					Backup_01.VIS.ShowMessageBoxOK := TRUE;
				END_IF
			// ---------------------------------------------------------------------------------------- 		
			// Comand refresh backup names
			ELSIF (Backup_01.CMD.RefreshDirectory) THEN
				// Show error message if there are oversized items
				IF(found_restore_dir) THEN
					// Reset command, set status, return to wait state
					found_restore_dir := FALSE;
					Backup_01.DAT.Status := "Restore backup complete";
					IF(Backup_01.PAR.ShowMessageBoxOK) THEN
						Backup_01.VIS.ShowMessageBoxOK := TRUE;
					END_IF
				ELSE
					Backup_01.DAT.Status := "Refreshed backup names";
				END_IF
			// ---------------------------------------------------------------------------------------- 		
			// Comand refresh backup information
			ELSIF (Backup_01.CMD.RefreshInfo) THEN
				// Directory does not contain a PLC backup
				IF(MpBackupCore_0.StatusID =  mpBACKUP_ERR_REQUEST_INFO_FAILED) THEN
					Backup_01.DAT.Status := "Can not find directory or backup information";
				ELSE
					Backup_01.DAT.Status := "Refreshed backup information";
				END_IF
			END_IF
			// Set status, return to wait state
			brsmemset(ADR(Backup_01.CMD), 0, SIZEOF(Backup_01.CMD));
			MpBackupCore_0.ErrorReset := TRUE;
			MpBackupCore_0();
			MpBackupCore_0.ErrorReset := FALSE;
			bac_state := BAC_WAIT;
		//**********************************************************************************************
		// Read directory information																	
		//**********************************************************************************************
		BAC_READ_DIR_0:
			// Show current state								
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr1), animation);
			// Clear all entrys, reset mappBackup function block																	
			brsmemset(ADR(Backup_01.DAT), 0, SIZEOF(Backup_01.DAT));
			Backup_01.DAT.BackupNum := 0;
			has_oversized_items := FALSE;
			
			// ---------------------------------------------------------------------------------------- 
			// Reset mappBackup function block																	
			MpBackupCore_0.Enable := 0;
			MpBackupCore_0();
			// ---------------------------------------------------------------------------------------- 		
			// Set values and get device dir															
			DInfo.enable 	:= 1;
			DInfo.pDevice	:= ADR(DeviceName);
			DInfo();
						
			// ---------------------------------------------------------------------------------------- 		
			// OK																																				
			IF (DInfo.status = OK) THEN
				first_boot := FALSE;
				bac_state := BAC_READ_DIR_1;
			ELSIF (DInfo.status = fiERR_DEVICE_MANAGER) THEN
				// On first boot skip devices that are not available
				IF (first_boot) THEN
					DeviceIdx := DeviceIdx + 1;
					IF(Backup_01.PAR.DeviceList[DeviceIdx] <> '') THEN
						brsstrcpy(ADR(DeviceName), ADR(Backup_01.PAR.DeviceList[DeviceIdx]));
						brsstrcpy(ADR(DeviceNameOld), ADR(Backup_01.PAR.DeviceList[DeviceIdx]));
						brsstrcpy(ADR(Backup_01.PAR.DeviceName), ADR(Backup_01.PAR.DeviceList[DeviceIdx]));
					ELSE
						// Set status, return to wait state
						brsmemset(ADR(Backup_01.CMD), 0, SIZEOF(Backup_01.CMD));
						first_boot := FALSE;
						bac_state := BAC_WAIT;
					END_IF
				// Create error message when file device is not available
				ELSE
					tmpWStr1 := "File device ";
					brwcsconv(ADR(tmpWStr2), ADR(DeviceName), brwU8toUC);
					brwcscat(ADR(tmpWStr1), ADR(tmpWStr2));
					brwcscat(ADR(tmpWStr1), ADR(" is unavailable"));
					bac_state := CreateError(ADR(Backup_01), DInfo.status, tmpWStr1, bac_state);
				END_IF
			// Error																	
			ELSIF (DInfo.status <> ERR_FUB_BUSY) THEN
				first_boot := FALSE;
				bac_state := CreateError(ADR(Backup_01), DInfo.status, "Error dir info", bac_state);
			END_IF
		//**********************************************************************************************
		// Open directory 																				
		//**********************************************************************************************
		BAC_READ_DIR_1:														
			// Show current state								
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr1), animation);

			DOpen.enable 	:= 1;
			DOpen.pDevice	:= ADR(DeviceName);
			DOpen.pName 	:= ADR(BACKUP_DIRECTORY);
			DOpen();
						
			// ---------------------------------------------------------------------------------------- 		
			// OK																																				
			IF (DOpen.status = OK) THEN
				bac_state := BAC_READ_DIR_2;				
				// Error
			ELSIF (DOpen.status <> ERR_FUB_BUSY) THEN
				bac_state := CreateError(ADR(Backup_01), DOpen.status, "Error dir open", bac_state);
			END_IF;
		//**********************************************************************************************
		// Read file directory information																
		//**********************************************************************************************
		BAC_READ_DIR_2:													
			// Show current state								
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr1), animation);

			DRead.enable 	:= 1;
			DRead.ident		:= DOpen.ident;
			DRead.pData 	:= ADR(lDirReadData);
			DRead.data_len 	:= SIZEOF(lDirReadData);
			DRead();
										
			// ---------------------------------------------------------------------------------------- 		
			// OK																																				
			IF (DRead.status = OK AND lDirReadData.Mode = fiDIRECTORY AND brsstrcmp(ADR(lDirReadData.Filename), ADR('.')) <> 0 AND brsstrcmp(ADR(lDirReadData.Filename), ADR('..')) <> 0 AND brsstrcmp(ADR(lDirReadData.Filename), ADR('System Volume Information')) <> 0) THEN
				// Make sure file name does not exceed maximum string size
				IF (brsstrlen(ADR(lDirReadData.Filename)) < BACKUP_NAME_LENGTH) THEN
					// Copy dir info to string
					brsmemset(ADR(tmpStr1), 0, SIZEOF(tmpStr1));
					brsstrcpy(ADR(tmpStr1), ADR(lDirReadData.Filename));
					// Found restore directory
					IF(brsstrcmp(ADR(Backup_01.PAR.UniqueName), ADR(tmpStr1)) = 0) THEN
						found_restore_dir := TRUE;
					ELSE
						// ------------------------------------------------------------------------------------ 		
						// Verify that we still have space in list												
						IF (Backup_01.DAT.BackupNum <= BACKUP_LIST_NUM) THEN
							InsertRecName(ADR(Backup_01), tmpStr1);
							// Error
						ELSE
							bac_state := CreateError(ADR(Backup_01), ERR_BAC_MAX_NUM, "Maximum number of backups reached", bac_state);
						END_IF
					END_IF
				ELSE
					has_oversized_items := TRUE;
				END_IF
			// Last entry reached
			ELSIF (DRead.status = fiERR_NO_MORE_ENTRIES) THEN 
				bac_state := BAC_READ_DIR_3;
			// Error		
			ELSIF (DRead.status <> ERR_FUB_BUSY AND DRead.status <> OK) THEN
				bac_state := CreateError(ADR(Backup_01), DRead.status, "Error backup list read", bac_state);
			END_IF
		//**********************************************************************************************
		// Close directory information																	
		//**********************************************************************************************
		BAC_READ_DIR_3:														
			// Show current state								
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr1), animation);

			DClose.enable 	:= 1;
			DClose.ident	:= DOpen.ident;
			DClose();
										
			// ---------------------------------------------------------------------------------------- 		
			// OK																																				
			IF (DClose.status = OK) THEN
				// Delete restore flag directory
				IF(found_restore_dir) THEN
					BackupName := Backup_01.PAR.UniqueName;
					bac_state := BAC_DIR_DELETE;
				// Finish directory reading
				ELSE
					bac_state := BAC_READ_DIR_4;
				END_IF
			// Error 		
			ELSIF (DClose.status <> ERR_FUB_BUSY) THEN
				bac_state := CreateError(ADR(Backup_01), DClose.status, "Error dir close", bac_state);
			END_IF
		//**********************************************************************************************
		// Finish directory information																	
		//**********************************************************************************************
		BAC_READ_DIR_4:
			// Show error message if there are oversized items												
			IF(has_oversized_items) THEN
				bac_state := CreateError(ADR(Backup_01), ERR_BAC_NAME_LENGTH, "One or more backup names exceeds maximum length", bac_state);
			ELSE
				// Get information from first entry
				IF(Backup_01.DAT.BackupNum > 0) THEN
					// Select new backup
					IF(Backup_01.CMD.Backup) THEN
						Backup_01.VIS.SelectedBackup := BackupName;
					// Select first entry
					ELSE
						BackupName := Backup_01.DAT.BackupNames[0];
					END_IF
					// Get information for selected backup
					Backup_01.CMD.RefreshInfo := TRUE;
					bac_state := BAC_CORE;
				ELSE
					bac_state := BAC_FINISH;
				END_IF
			END_IF
		//**********************************************************************************************
		// Delete selected directory
		//**********************************************************************************************
		BAC_DIR_DELETE:
			// Show current state
			animation := WorkingStatus(ADR(Backup_01), ADR("Deleting backup..."), animation);

			// ----------------------------------------------------------------------------------------
			// Initialize directory delete structure
			DDelete.enable	:= 1;
			DDelete.pDevice := ADR(DeviceName);
			DDelete.pName 	:= ADR(BackupName);
			DDelete();

			// ----------------------------------------------------------------------------------------
			// OK
			IF (DDelete.status = OK) THEN
				// Deleted restore directory
				IF(found_restore_dir) THEN
					bac_state := BAC_READ_DIR_4;
				// Deleted standard backup directory
				ELSE
					// Show status and return to wait state
					Backup_01.DAT.Status := "Deleted backup";
					bac_state := BAC_READ_DIR_0;
				END_IF
			// Error
			ELSIF (DDelete.status <> ERR_FUB_BUSY) THEN
				IF(DDelete.status = fiERR_DIR_NOT_EXIST) THEN
					bac_state := CreateError(ADR(Backup_01), DDelete.status, "Can not find backup directory", bac_state);
				ELSE
					bac_state := CreateError(ADR(Backup_01), DDelete.status, "Error deleting backup", bac_state);
				END_IF
			END_IF
		//**********************************************************************************************
		// Create selected directory
		//**********************************************************************************************
		BAC_DIR_CREATE:
			// Show current state
			animation := WorkingStatus(ADR(Backup_01), ADR(tmpWStr1), animation);

			// ----------------------------------------------------------------------------------------
			// Initialize directory delete structure
			DCreate.enable	:= 1;
			DCreate.pDevice := ADR(DeviceName);
			DCreate.pName 	:= ADR(Backup_01.PAR.UniqueName);
			DCreate();

			// ----------------------------------------------------------------------------------------
			// OK
			IF (DCreate.status = OK OR DCreate.status = fiERR_DIR_ALREADY_EXIST) THEN
				// Start restoring backup
				bac_state := BAC_CORE;
			// Error
			ELSIF (DCreate.status <> ERR_FUB_BUSY) THEN
				bac_state := CreateError(ADR(Backup_01), DCreate.status, "Could not create restore flag directory", bac_state);
			END_IF
		// --------------------------------------------------------------------------------------------------------------------
		// Error 
		// --------------------------------------------------------------------------------------------------------------------					
		BAC_ERROR:
			Backup_01.DAT.Status := "Acknowledge error to trigger new command";
			
			// Make sure we dont exceed maximum number of web clients
			IF(Backup_01.PAR.ShowMessageBoxError) THEN
				Backup_01.VIS.ShowMessageBoxError := TRUE;
			END_IF
			// --------------------------------------------------------------------------------------------------------------------	
			// Return to idle state
			IF (Backup_01.CMD.ErrorReset) THEN
				// Reset function blocks
				MpBackupCore_0.ErrorReset := TRUE;
				MpBackupCore_0();
				MpBackupCore_0.ErrorReset := FALSE;
				
				// Reset error structure
				brsmemset(ADR(Backup_01.ERR), 0, SIZEOF(Backup_01.ERR));
				Backup_01.DAT.Status := "";
				Backup_01.VIS.ShowMessageBoxError := FALSE;
				bac_state := BAC_WAIT;
			END_IF;	
			brsmemset(ADR(Backup_01.CMD), 0, SIZEOF(Backup_01.CMD));
	END_CASE
	
	// --------------------------------------------------------------------------------------------------------------------
	// Cyclic function call
	MpBackupCore_0.Enable := 1;
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
