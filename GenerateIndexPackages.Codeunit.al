codeunit 99900 "PTE Generate Index Package"
{
    trigger OnRun()
    var
        DataCompression: Codeunit "Data Compression";
        TempBlob: Codeunit "Temp Blob";
        TableExtensions: Dictionary of [Integer, Text];
        Dependencies: List of [Guid];
        is: InStream;
        os: OutStream;
        clientFileName: Text;
        ObjId, NextObjId : Integer;
    begin
        NextObjId := 99900;
        TableExtensions := CreateObjectDictionairy();
        Dependencies := CreateDependencies();
        DataCompression.CreateZipArchive();

        foreach ObjId in TableExtensions.Keys() do
            CreateTableExtension(ObjId, TableExtensions.Get(ObjId), NextObjId, DataCompression);

        AddAppJson(Dependencies, DataCompression);

        DataCompression.SaveZipArchive(os);
        TempBlob.CreateInStream(is);
        clientFileName := StrSubstNo('KeyExtension.zip', CurrentDateTime);
        DownloadFromStream(is, '', '', '', clientFileName);
        DataCompression.CloseZipArchive();
    end;

    local procedure AddAppJson(Dependencies: List of [Guid]; var DataCompression: Codeunit "Data Compression")
    var
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
    begin

        TempBlob.CreateOutStream(OutStr);

        OutStr.WRITETEXT(
            '{' + CRLF +
            '"id": "' + delchr(format(CreateGuid()), '=', '{}') + '",' + CRLF +
            '"name": "Index Package",' + CRLF +
            '"publisher": "Marije Jennifer Brummel",' + CRLF +
            '"version": "0.0.0.0",' + CRLF +
            '"dependencies": [' + CRLF +
            GetDependencies(Dependencies) +
            '],' + CRLF +
            '"platform": "1.0.0.0",' + CRLF +
            '"application": "22.0.0.0",' + CRLF +
            '"idRanges": [' + CRLF +
            '{' + CRLF +
            '"from": 99900,' + CRLF +
            '"to": 99999' + CRLF +
            '}' + CRLF +
            '],' + CRLF +
            '"resourceExposurePolicy": {' + CRLF +
            '"allowDebugging": true,' + CRLF +
            '"allowDownloadingSource": true,' + CRLF +
            '"includeSourceInSymbolFile": true' + CRLF +
            ' },' + CRLF +
            '   "runtime": "11.0"' + CRLF +
            ' }');

        TempBlob.CreateInStream(InStr);
        DataCompression.AddEntry(InStr, 'app.json');
    end;

    local procedure GetDependencies(Dependencies: List of [Guid]): Text
    var
        NavApp: Record "NAV App Installed App";
        Dependency, AllDepedencies : Text;
        AppId: Guid;
    begin
        foreach AppId in Dependencies do begin
            NavApp.SetRange("App ID", AppId);
            NavApp.FindFirst();
            Dependency := GetDependency(NavApp);
            if AllDepedencies <> '' then
                AllDepedencies += ',';
            AllDepedencies += Dependency;
        end;
        exit(AllDepedencies);
    end;

    local procedure GetDependency(NavApp: Record "NAV App Installed App"): Text
    var
        Value: Text;
    begin
        Value := '{' + CRLF() +
        '   "name": "' + NavApp.Name + '", "id": "' + DelChr(Format(NavApp."App ID"), '=', '{}') + '", ' +
        '   "publisher": "' + NavApp.Publisher + '", "version": "0.0.0.0"' +
        '}' + CRLF;
        exit(Value);
    end;

    local procedure CreateTableExtension(ObjId: Integer; TableName: Text; var NextObjId: Integer; var DataCompression: Codeunit "Data Compression")
    var
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr);

        OutStr.WRITETEXT('tableextension ' + format(NextObjId) + ' "PTE ' + ObjName(ObjId) + '" extends "' + ObjName(ObjId) + '"' +
          CRLF +
          '{' + CRLF +
          'keys' + CRLF() +
          '{' + CRLF +
          GetKeys(ObjId, TableName) +
          '}' + CRLF +
          '}'
          );

        NextObjId += 1;
        TempBlob.CreateInStream(InStr);
        DataCompression.AddEntry(InStr, DelChr(ObjName(ObjId), '=', ' \/.') + 'TableExt.al');
    end;

    local procedure GetKeys(ObjId: Integer; TableName: Text): Text
    var
        MissingIndex: Record "Database Missing Indexes";
        KeyId: Integer;
        NewKey: Text;
        NewKeys: Text;
    begin
        KeyId := 0;
        MissingIndex.SetRange("Table Name", TableName);

        MissingIndex.FindSet();
        repeat
            NewKey := 'key(' + GetKeyName(MissingIndex, KeyId) + '; ' + GetKeyFields(ObjId, MissingIndex) + ' ) { ' + GetIncludedColumns(ObjId, MissingIndex) + ' }' + CRLF;
            KeyId += 1;
            NewKeys += NewKey;
        until MissingIndex.Next() = 0;
        exit(NewKeys);
    end;

    local procedure GetIncludedColumns(ObjId: Integer; MissingIndex: Record "Database Missing Indexes"): Text
    var
        KeyFields: List of [Text];
        MyKey, KeyField : Text;
    begin
        if MissingIndex."Index Include Columns" = '' then
            exit('');

        KeyFields := DelChr(MissingIndex."Index Include Columns", '=', '[]').Split(',');
        foreach KeyField in KeyFields do begin
            if MyKey <> '' then
                MyKey += ',';
            MyKey += '"' + GetBCFieldName(ObjId, KeyField) + '"' // ToDo - Convert SQL Field name to AL Field Name
        end;
        exit('IncludedFields = ' + MyKey + ';');
    end;

    local procedure GetKeyName(MissingIndex: Record "Database Missing Indexes"; KeyId: Integer): Text
    begin
        exit(DelChr(MissingIndex."Table Name") + Format(KeyId));
    end;

    local procedure GetKeyFields(ObjId: Integer; MissingIndex: Record "Database Missing Indexes"): Text
    var
        KeyFields: List of [Text];
        MyKey, KeyField : Text;
    begin
        KeyFields := DelChr(MissingIndex."Index Equality Columns", '=', '[]').Split(',');
        foreach KeyField in KeyFields do begin
            if MyKey <> '' then
                MyKey += ',';
            MyKey += '"' + GetBCFieldName(ObjId, KeyField) + '"' // ToDo - Convert SQL Field name to AL Field Name
        end;

        if MissingIndex."Index Inequality Columns" <> '' then begin
            KeyFields := DelChr(MissingIndex."Index Inequality Columns", '=', '[]').Split(',');
            foreach KeyField in KeyFields do begin
                if MyKey <> '' then
                    MyKey += ',';
                MyKey += '"' + GetBCFieldName(ObjId, KeyField) + '"' // ToDo - Convert SQL Field name to AL Field Name
            end;
        end;

        exit(MyKey);
    end;

    local procedure GetBCFieldName(ObjId: Integer; FieldName: Text): Text
    var
        Fld: Record Field;
    begin
        FieldName := DelChr(FieldName, '<>', ' $');
        Fld.SetRange(TableNo, ObjId);
        Fld.SetRange(FieldName, FieldName);
        if Fld.FindFirst() then
            exit(FieldName);
        Fld.SetFilter(FieldName, FieldName.Replace('_', '?'));
        if Fld.FindFirst() then
            exit(Fld.FieldName);
        if FieldName = 'systemId' then
            exit('SystemId');
        if FieldName = 'systemCreatedAt' then
            exit('SystemCreatedAt');
        if FieldName = 'systemCreatedBy' then
            exit('SystemCreatedBy');
        if FieldName = 'systemModifiedAt' then
            exit('SystemModifiedAt');
        if FieldName = 'systemModifiedBy' then
            exit('SystemModifiedBy');
        Error('Field Not Found ' + FieldName);
    end;

    local procedure ObjName(ObjId: Integer): Text
    var
        AllObj: Record AllObj;
    begin
        AllObj.Get(AllObj."Object Type"::Table, ObjId);
        exit(AllObj."Object Name");
    end;

    local procedure CreateDependencies(): List of [Guid]
    var
        MissingIndex: Record "Database Missing Indexes";
        Dependencies: List of [Guid];
    begin
        if MissingIndex.FindSet() then
            repeat
                if not Dependencies.Contains(MissingIndex."Extension Id") then
                    Dependencies.Add(MissingIndex."Extension Id");
            until MissingIndex.Next() = 0;
        exit(Dependencies);
    end;

    local procedure CreateObjectDictionairy(): Dictionary of [Integer, Text]
    var
        MissingIndex: Record "Database Missing Indexes";
        TableExtensions: Dictionary of [Integer, Text];
        ObjId: Integer;
    begin
        if MissingIndex.FindSet() then
            repeat
                if not MissingIndex."Table Name".Contains('VSIFT') then begin
                    if not MissingIndex."Table Name".EndsWith('$ext') then begin // Ignore Table Extensions for now...
                        ObjId := FindTableID(MissingIndex."Table Name");
                        if not TableExtensions.ContainsKey(ObjId) then
                            TableExtensions.Add(ObjId, MissingIndex."Table Name");
                    end;
                end;
            until MissingIndex.Next() = 0;
        exit(TableExtensions);
    end;

    local procedure FindTableID(Value: Text): Integer
    var
        Obj: Record AllObj;
    begin
        Obj.SetRange("Object Type", Obj."Object Type"::Table);
        Obj.SetRange("Object Name", Value);
        if Obj.FindFirst() then
            exit(Obj."Object ID");
        Obj.SetFilter("Object Name", Value.Replace('_', '?'));
        Obj.FindFirst();
        exit(Obj."Object ID");
    end;

    local procedure CRLF(): Text[2]
    var
        LineFeed: Text[2];
    begin
        LineFeed[1] := 13;
        LineFeed[2] := 10;
        exit(LineFeed);
    end;

}