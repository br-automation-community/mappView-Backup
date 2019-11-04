PROGRAM _INIT
	// ----------------------------------------------------------------------------------------
END_PROGRAM

PROGRAM _CYCLIC
	// ------------------------------------------------------------------------------------------------
	// Generate device name list
	brsmemset(ADR(VisDeviceList), 0, SIZEOF(VisDeviceList));
	FOR lx := 0 TO SIZEOF(VisDeviceList)/SIZEOF(VisDeviceList[0]) - 1 DO 
		IF (DeviceList[lx] <> '') THEN
			String2DataProvider(ADR(DeviceList), ADR(VisDeviceList));
		END_IF
	END_FOR;
	
	// ------------------------------------------------------------------------------------------------
	// Main backup functionc all
	MpBackupCore_0.MpLink := ADR(gBackupCore);
	MpBackupCore_0.Enable := 1;
	MpBackupCore_0.DeviceName := ADR(DeviceName);
	MpBackupCore_0();
END_PROGRAM

PROGRAM _EXIT
	MpBackupCore_0.Enable := 0;
	MpBackupCore_0();
END_PROGRAM
