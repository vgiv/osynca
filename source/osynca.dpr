{$APPTYPE CONSOLE}

{$O+}
{$Warnings off}

Uses
  SysUtils, Windows, FileCtrl, IniFiles, Classes, DateUtils;

Const
  Ver = 'v.0.992';
  LogFileName = 'osynca.log';
  SecsInDay = 24*60*60; // number of seconds in day for TDateTime conversion
  ProgramMark = ' Osynca: ';
  MaxDirsQ = 63; // set maximum number of directories (now 64)
  IniFileName0 = 'osynca.ini';
  SyncFileName0 = 'sync.ini';

Var
  flist, fupdate, fremove, fbackup, flog, femptydirs: TextFile;
//
  IniFile, SyncFile: TIniFile;
//
  ListName, RemoteListName, ProgramDirectory,
    FullIniFileName, UpdateArcListName, RemoveArcListName,
    BackupArcListName, SyncDir, FullSyncFileName: TFileName;
//
  Computer1, Computer2, Direction, Computer, RemoteComputer, Volume: string;
//
  ComputerList, RemoteComputerList: TStringList;
  qCreate, qUpdate, qRemove, qEmptyDirs: integer;
//
  FilOnly, InitOnly: boolean;
//
  dtime: integer;
//
  Time0: TDateTime;
//
  EmptyInitialDir: boolean;
//
  EDListName: TFileName;
  EDPrefix: string;
  OutED: boolean;

function AddDirBackSlash( const Dir: TFileName ): TFileName;
// Add slash to directory name if need
begin
  Result := Dir;
  if Result[ Length(Result) ] <> '\' then
    Result := Result + '\';
end; {AddDirBackSlash}

function QFN( const fn: TFileName ): TFileName;
// Quote file name if need
begin
  Result := fn;
  if ( Pos( ' ', Result ) <> 0 ) or ( Pos( '&', Result ) <> 0 ) then
    Result :=  '"' + Result + '"';
end; {QFN}

function StrAnsiToOem( const aStr: String ): String;
// Ansi to Oem string conversion
Var
  Len: integer;
begin
  Result := '';
  Len := Length(aStr);
  if Len=0 then
    Exit;
  SetLength(Result, Len);
  CharToOemBuff( PChar(aStr), PChar(Result), Len );
end; {StrAnsiToOem}

procedure ToConsole( const Msg: string );
begin
  WriteLn( ProgramMark + StrAnsiToOem(Msg) );
end; {ToConsole}

procedure TimeToConsole;
// Output elapsed time to console
begin
  ToConsole( Format( '%0.2f sec elapsed', [(Now-Time0)*SecsInDay] ) );
end; {TimeToConsole}

procedure ToLog( const Msg: string );
// Output to log and to console
begin
  ToConsole( Msg ); 
  WriteLn( flog, Msg ); 
end; {ToLog}

procedure ToCreate( const fnamex: TFileName );
// fnamex is the filename, possibly, without a disk letter
begin
  WriteLn( fupdate, QFN(fnamex) ); 
  ToLog( '+ ' + QFN(fnamex) ); 
  Inc( qCreate );
end; {ToCreate}

procedure ToUpdate( const fnamex: TFileName );
// fnamex is the filename, possibly, without a disk letter
begin
  WriteLn( fbackup, QFN(fnamex) );  
  WriteLn( fupdate, QFN(fnamex) );  
  ToLog( '! ' + QFN(fnamex) ); 
  Inc( qUpdate );
end; {ToUpdate}

procedure ToRemove( const fnamex: TFileName );
// fnamex is the filename, possibly, without a disk letter
begin
  WriteLn( fremove, QFN(fnamex) );  
  ToLog( '- ' + QFN(fnamex) ); 
  Inc( qRemove );
end; {ToRemove}

procedure ToEmptyDirs( const fname: TFileName );
begin
//
  if not OutED then
    Exit;
//
  Append( femptydirs );
  WriteLn( femptydirs, StrAnsiToOem( EDPrefix + ' ' + QFN(fname) ) );  
  ToLog( 'EMPTY DIR: ' + QFN(fname) ); 
  Inc( qEmptyDirs );
  CloseFile( femptydirs );
//
end; {ToRemove}

Procedure AddToList( const fname: TFileName; const SRec: TSearchRec );
// add filename to ComputerList
Var
  pDT: PDateTime;
begin
//
  New( pDT );
  pDT^ := FileDateToDateTime( SRec.Time );
// Add filename and date to list
  with ComputerList do 
    AddObject( fname, TObject(pDT) );
//
end; {AddToList}

Procedure ScanDirToComputerList( const DirMask: TFileName; Var EmptyDir: boolean );
// Recursive scanning files and adding them to ComputerList
Var
  SRec: TSearchRec;
  fName: TFileName;
  SearchResult: integer;
  DirPath: TFileName;
  FileMask: string;
  i: integer;
  EmptySubdir: boolean;
begin

// Parse DirMask to DirPath and FileMask
  DirPath := DirMask;
  FileMask := '*.*';
  for i := Length(DirMask) downto 1 do
    if DirMask[i]='\' then // the end of mask
    begin
      DirPath := Copy( DirMask, 1, i );
      if i<Length(DirMask) then
        FileMask := Copy( DirMask, i+1, Length(DirMask)-i );
      Break;
    end;
  DirPath := AddDirBackSlash( DirPath );

// Seach for files
  EmptyDir := True;
  SearchResult := FindFirst( DirPath + FileMask, faAnyFile, SRec );
  while SearchResult=0 do
    with SRec do
    begin
      if (Attr and faDirectory) = 0 then
      begin
          EmptyDir := False;
          fName := DirPath + Name;
//          fName := AnsiUppercase( DirPath ) + AnsiLowerCase( Name );
          AddToList( fname, SRec );
      end;
      SearchResult := FindNext( SRec )
    end;

// Search for subdirectories
  SearchResult := FindFirst( DirPath + '*.*', faDirectory, SRec );
  while SearchResult=0 do
    with SRec do
    begin
      if (Attr and faDirectory <> 0 ) and (Name <> '.') and (Name <> '..') then
      begin
        ScanDirToComputerList( AddDirBackSlash( DirPath + Name ) + FileMask, EmptySubdir );
        EmptyDir := EmptyDir and EmptySubdir;
      end;
      SearchResult := FindNext( SRec );
    end;

  if OutED and EmptyDir then
    ToEmptyDirs( DirPath );

end; {ScanDirToComputerList}

procedure ReplaceStr( Var s: string; const s1, s2: string );
// Replace s1 by s2 in s
Var
  i: integer;
begin
  i := Pos( s1, s );
  if i>0 then
  begin
    Delete( s, i, Length(s1) );
    Insert( s2, s, i );
  end;
end; {ReplaceStr}

procedure ReadIniFile;
Var
  SecName: string;
begin

// Does ini file exist?
  if not FileExists(FullIniFileName) then
    raise Exception.Create( 'Configuration file ' + QFN(FullIniFileName) + ' cannot be found' );
  ToConsole( 'Configuration file: ' + QFN(FullIniFileName) );

// Prepare ini file
  IniFile := TIniFile.Create(FullIniFileName);

  with IniFile do
  begin
    SecName := 'General';
    Direction := ReadString( SecName, 'DIRECTION', '' );
    SyncDir := ReadString( SecName, 'SDIR', '' );
    EDListName := ReadString( SecName, 'EDLISTNAME', '' );
    EDPrefix := ReadString( SecName, 'EDPREFIX', '' );
  end;

  IniFile.Free;

  FullSyncFileName := SyncDir + SyncFileName0;

end; {ReadIniFile}

procedure FirstReadSyncFile;
Var
  SecName: string;
begin

// Does ini file exist?
  if not FileExists(FullSyncFileName) then
    raise Exception.Create( 'Sync file ' + QFN(FullSyncFileName) + ' cannot be found' );
  ToConsole( 'Sync file: ' + QFN(FullSyncFileName) );

// Prepare ini file
  SyncFile := TIniFile.Create(FullSyncFileName);

  with SyncFile do
  begin
    SecName := 'General';

    Computer1 := ReadString( SecName, 'COMPUTER1', '' );
    Computer2 := ReadString( SecName, 'COMPUTER2', '' );
    Volume := ReadString( SecName, 'Volume', '' );

// Check parameters
    if (Computer1='') or (Computer2='') or (SyncDir='') then
      raise Exception.Create( 'No mandatory parameters in INI file' );

    if (Volume='') or (Length(Volume)<>2) or (Volume[2]<>':') then
      raise Exception.Create( 'Bad VOLUME in INI file' );

    if Direction = '12' then
    begin
      Computer := Computer1;
      RemoteComputer := Computer2;
    end else if Direction = '21' then
    begin
      Computer := Computer2;
      RemoteComputer := Computer1;
    end else
      raise Exception.Create( 'Wrong DIRECTION in INI file' );

    try
      dtime := ReadInteger( SecName, 'DTIME', 3 );
    except
      raise Exception.Create( 'Wrong DTIME in INI file' );
    end;

    ListName := SyncDir + Computer + '.fil';
    RemoteListName := SyncDir + RemoteComputer + '.fil';
    UpdateArcListName := SyncDir + Computer + '2' + RemoteComputer + '.lst';
    RemoveArcListName := SyncDir + RemoteComputer + '_remove.lst';
    BackupArcListName := SyncDir + RemoteComputer + '_backup.lst';

  end;

  SyncFile.Free;

end; {FirstReadSyncFile}


procedure MakeComputerList;
Var
  SecName: string;
  i: integer;
  Dir: TFileName;
begin

  ComputerList := TStringList.Create;

// ... and its counters
  qCreate := 0;
  qUpdate := 0;
  qRemove := 0;

// Prepare ini file
  SyncFile := TIniFile.Create(FullSyncFileName);

  with SyncFile do
  begin
    OutED := (EDListName<>'');

// prepare empty file for list of empty directories
    if OutED then
    begin
      Assign( femptydirs, EDListName );
      Rewrite( femptydirs );
      CloseFile( femptydirs );
    end;

// read list of directories
    SecName := 'Directories';
    for i := 0 to MaxDirsQ do
    begin
      Dir := ReadString( SecName, Format('DIR%d', [i]), '' );
      if Dir<>'' then
      begin
        ToConsole( 'Scanning directory ' + QFN(Dir) );
        ScanDirToComputerList( Dir, EmptyInitialDir );
      end;
    end;

  end;

  SyncFile.Free;

// delete file if it is empty
  if OutED and (qEmptyDirs=0) then
    DeleteFile( PChar(EDListName) );

end; {MakeComputerList}

procedure WriteComputerList;
// writing ComputerList to file ListName
Var
  i: integer;
  pDT: PDateTime;
begin

  Assign( flist, ListName );
  Rewrite( flist );
  with ComputerList do
    for i := 0 to Count-1 do
    begin
      pDT := Pointer( Objects[i] );
      WriteLn( flist, Format( '"%s",', [Strings[i]]), FormatDateTime( ShortDateFormat, pDT^ ) );
    end;
  CloseFile( flist );

end; {WriteComputerList}

procedure ReadRemoteList;
// Read remote ComputerList from file RemoteListName
Var
  s: string;
  i: integer;
  fname: TFileName;
  pDT: PDateTime;
begin

// does RemoteListName exist?
  if not FileExists(RemoteListName) then
    raise Exception.Create( 'Nothing to compare' );

  RemoteComputerList := TStringList.Create;

  Assign( flist, RemoteListName );
  Reset( flist );
  while not SeekEof( flist ) do
  begin
    ReadLn( flist, s );
// line must be empty or start from "
    if (s='') or (s[1]<>'"') then
      raise Exception.Create( 'Bad format of remote list' )
    else
      Delete( s, 1, 1 );
//
    i := Pos( '"', s ); // find the 2nd "
    if i<>0 then
    begin
//    Extract filename
      fname := Copy( s, 1, i-1 );
      Delete( s, 1, i+1 );
      New( pDT );
//    Extract date
      try
         pDT^ := StrToDateTime( s );
      except
        raise Exception.Create( 'Bad format of remote list (2)' );
      end;
//    Add record to the list
      with RemoteComputerList do
        AddObject( fname, TObject(pDT) );
    end
    else
      raise Exception.Create( 'Bad format of remote list (3)' );
  end;
  CloseFile( flist );

end; {ReadRemoteList}

function DateTimeDiff( const DT1, DT2: TDateTime ): longint;
// difference of TDateTime in seconds
begin

  Result := Round( DT1*SecsInDay ) - Round( DT2*SecsInDay );

end; {DateTimeDiff}

procedure CompareLists;
Var
  i, j, k: integer;
  c: integer;
  pDT1, pDT2: PDateTime;
begin

// Open filelists
  Assign( fupdate, UpdateArcListName );
  Rewrite( fupdate );
  Assign( fremove, RemoveArcListName );
  Rewrite( fremove );
  Assign( fbackup, BackupArcListName );
  Rewrite( fbackup );

// Compare filelists
  i := 0;
  j := 0;
  while (i<ComputerList.Count) and (j<RemoteComputerList.Count) do
  begin
    c := AnsiCompareStr( ComputerList[i], RemoteComputerList[j] ); // Ansi is important!
    if c<0 then // if the file in 1st list is unique
    begin
      ToCreate( ComputerList[i] );
      Inc( i );
    end
    else if c>0 then // if the file in 2nd list is unique
    begin
      ToRemove( RemoteComputerList[j] );
      Inc( j );
    end
    else // if the file exists in both lists
    begin
      pDT1 := Pointer( ComputerList.Objects[i] );
      pDT2 := Pointer( RemoteComputerList.Objects[j] );
      if DateTimeDiff( pDT1^, pDT2^ ) > dtime then // if the file in 1st list is newer 
        ToUpdate( ComputerList[i] );
      Inc( i );
      Inc( j );
    end;
  end;

// Push the rest of 1st list
  with ComputerList do
    if i<Count then
      for k := i to Count-1 do
        ToCreate( ComputerList[k] );

// ... or push the rest of 2nd list
  with RemoteComputerList do
    if j<Count then
      for k := j to Count-1 do
        ToRemove( RemoteComputerList[k] );

// Close filelists
  CloseFile( fupdate );
  CloseFile( fremove );
  CloseFile( fbackup );

// Delete empty files, if any
  if (qCreate=0) and (qUpdate=0) then
    DeleteFile( PChar(UpdateArcListName) );
  if qRemove=0 then
    DeleteFile( PChar(RemoveArcListName) );
  if qUpdate=0 then
    DeleteFile( PChar(BackupArcListName) );

end; {CompareLists}

procedure TerminateProgram( const Msg: string );
begin

  ToLog( 'Error: ' + Msg );
  CloseFile( flog );
  Halt( 1 );

end; {TerminateProgram}

procedure ParseCmdLine;
// Parse command line
Var
  param: string;
  IniFileName: TFileName;
  i: integer;
begin

  FilOnly := False;
  InitOnly := False;
  IniFileName := '';

  for i := 1 to ParamCount do
  begin
    param := ParamStr(i);
    if param[1]='/' then
    begin
      if (Length(param)>1) then 
      if param[2]='f' then 
        FilOnly := True
      else if param[2]='i' then 
        InitOnly := True
      else
        raise Exception.Create( 'Unknown switch ' + param );
    end else if IniFileName='' then
      IniFileName := param
    else
      raise Exception.Create( 'Configuration file must be unique' );
  end;

  if FilOnly and InitOnly then
    raise Exception.Create( 'Keys /f and /i cannot be used together' );

// Set configuration file name
  if IniFileName = '' then
    IniFileName := IniFileName0;
  if IniFileName = ExtractFileName(IniFileName) then
  begin
    ProgramDirectory := ExtractFileDir( ParamStr(0) );
    FullIniFileName := ProgramDirectory + '\' + IniFileName;
  end else
    FullIniFileName := IniFileName;

end; {ParseCmdLine}

procedure CreateBatFiles;
// creating bat files

  procedure CreateBatFile( finname, foutname: TFileName );
  Var
    fin, fout: TextFile;
    s: string;
  begin
    Assign( fin, finname );
    Reset( fin );
    Assign( fout, foutname );
    Rewrite( fout );
    while not Eof( fin ) do
    begin
      ReadLn( fin, s );
      if Pos( 'rem THIS IS A TEMPLATE OF', s )<>0 then
        Continue;
      ReplaceStr( s, '__DIRECTION__', Direction );
      ReplaceStr( s, '__COMPUTER1__', Computer1 );
      ReplaceStr( s, '__COMPUTER2__', Computer2 );
      ReplaceStr( s, '__VOLUME__', Volume );
      ReplaceStr( s, '__SDIR__', SyncDir );
      WriteLn( fout, s );
    end;
    CloseFile( fin );
    CloseFile( fout );
  end;

begin

  try 
    CreateBatFile( 'put.bat0', 'put.bat' );
    CreateBatFile( 'get.bat0', 'get.bat' );
  except
    raise Exception.Create( 'Bat files cannot be created' );
  end;

end; {CreateBatFiles}

begin

  Time0 := Now;

  ToConsole( Ver );

// Start log
  Assign( flog, LogFileName );
  if FileExists( LogFileName ) then
    Append( flog )
  else
    Rewrite( flog );
  WriteLn( flog, '=== ', DateTimeToStr( Now ), ' Osynca ',  Ver, ' ===' );

// Set date format
  ShortDateFormat := 'yyyy-mm-dd hh:nn:ss';
  DateSeparator := '-';

  try

// Parse command line
    ParseCmdLine;

// Read general parameters
    ReadIniFile;

// Read syncronization parameters
    FirstReadSyncFile;

    if InitOnly then
    begin
      CreateBatFiles;
      ToLog( 'Bat files are created' );
      CloseFile( flog );
      TimeToConsole;
      Exit;
    end;

// Make local list of files (and list of empty directories, if need)
    MakeComputerList;

// Sort local list of files
    ComputerList.Sort;

// ... and write it
    WriteComputerList;

// If we only need *.fil file
    if FilOnly then
    begin
      ToLog( 'File ' + QFN(ListName) + ' was created or updated' );
      CloseFile( flog );
      TimeToConsole;
      Exit;
    end;

// ... otherwise we need to compare files

// Read remote file list
    ReadRemoteList;
  except
    on E: Exception do
      TerminateProgram( E.Message );
  end;

// Compare lists
  CompareLists;

// Close log
  CloseFile( flog );

// Output statistics

  ToConsole( Format( 'File(s) found: %d', [ComputerList.Count] ) );
  ToConsole( Format( 'File(s) to create/update/remove found: %d/%d/%d', [qCreate, qUpdate, qRemove] ) );
  if OutED then
    ToConsole( Format( 'Empty director(y/ies) found: %d', [qEmptyDirs] ) );
  TimeToConsole;

end.
