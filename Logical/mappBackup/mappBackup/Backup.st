PROGRAM _INIT
	// ----------------------------------------------------------------------------------------
	MpBackupCore_0.Enable := 1;
	MpBackupCore_0.MpLink := ADR(gBackupCore);
	MpBackupCore_0.Name := ADR(BackupName);
END_PROGRAM

PROGRAM _CYCLIC
//	// ------------------------------------------------------------------------------------------------
//	// Generate device name list
//	brsmemset(ADR(VisDeviceList), 0, SIZEOF(VisDeviceList));
//	FOR lx := 0 TO SIZEOF(VisDeviceList)/SIZEOF(VisDeviceList[0]) - 1 DO 
//		IF (DeviceList[lx] <> '') THEN
//			String2DataProvider(ADR(DeviceList), ADR(VisDeviceList));
//		END_IF
//	END_FOR;
	
	// ------------------------------------------------------------------------------------------------
	// Main backup functionc all
	MpBackupCore_0.DeviceName := ADR(SelectedDevice);
	MpBackupCore_0();
	
	// Reset command on error
	IF(EDGEPOS(MpBackupCore_0.Error)) THEN
		MpBackupCore_0.Create := FALSE;
		MpBackupCore_0.Install := FALSE;
		MpBackupCore_0.RequestInfo := FALSE;
	END_IF

	// Reset command error reset
	IF(EDGENEG(MpBackupCore_0.Error)) THEN
		MpBackupCore_0.ErrorReset := FALSE;
	END_IF

	// Reset command when done
	IF(EDGEPOS(MpBackupCore_0.CommandDone)) THEN
		MpBackupCore_0.Create := FALSE;
		MpBackupCore_0.Install := FALSE;
		MpBackupCore_0.RequestInfo := FALSE;
	END_IF
	
END_PROGRAM

PROGRAM _EXIT
	MpBackupCore_0.Enable := 0;
	MpBackupCore_0();
END_PROGRAM
