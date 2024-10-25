{ ***************************************************************************

  Copyright (c) 2016-2024 Kike P�rez / Jens Fudickar

  Unit        : Quick.Logger.Provider.StringList
  Description : Log StringList Provider
  Author      : Jens Fudickar
  Version     : 1.23
  Created     : 12/28/2023
  Modified    : 09/10/2024

  This file is part of QuickLogger: https://github.com/exilon/QuickLogger

  ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  *************************************************************************** }
unit Quick.Logger.Provider.StringList;

interface

{$I QuickLib.inc}

uses
  System.Classes,
{$IFDEF MSWINDOWS}
  WinApi.Windows,
{$IFDEF DELPHIXE8_UP}
  Quick.Json.Serializer,
{$ENDIF}
{$ENDIF}
{$IFDEF DELPHILINUX}
  Quick.SyncObjs.Linux.Compatibility,
{$ENDIF}
  System.SysUtils,
  Generics.Collections,
  Quick.Commons,
  Quick.Logger;

type

  TLogStringListProvider = class(TLogProviderBase)
  private
    fIncludeLogItems: Boolean;
    fintLogList: TStringList;
    FLogList: TStrings;
    fMaxSize: Int64;
    fShowEventTypes: Boolean;
    fShowTimeStamp: Boolean;
    CS: TRTLCriticalSection;
    function GetLogList: TStrings;
  public
    constructor Create; override;
    destructor Destroy; override;
    // This property defines if the log items should be cloned to the object property of the item list.
    property IncludeLogItems: Boolean read fIncludeLogItems write fIncludeLogItems default false;
{$IFDEF DELPHIXE8_UP}[TNotSerializableProperty]{$ENDIF}
    // Attention: When assigning an external stringlist to the property and IncludeLogItems = true you have to ensure
    // that the external list.ownsobjects is true
    property LogList: TStrings read GetLogList write FLogList;
    property MaxSize: Int64 read fMaxSize write fMaxSize;
    property ShowEventTypes: Boolean read fShowEventTypes write fShowEventTypes;
    property ShowTimeStamp: Boolean read fShowTimeStamp write fShowTimeStamp;
    procedure Init; override;
    procedure Restart; override;
    procedure WriteLog (cLogItem: TLogItem); override;
    procedure Clear;
  end;

var
  GlobalLogStringListProvider: TLogStringListProvider;

implementation


constructor TLogStringListProvider.Create;
begin
  inherited;

  {$IF Defined(MSWINDOWS) OR Defined(DELPHILINUX)}
  InitializeCriticalSection (CS);
  {$ELSE}
    InitCriticalSection (CS);
  {$ENDIF}

  LogLevel := LOG_ALL;
  fMaxSize := 0;
  fShowEventTypes := False;
  fShowTimeStamp := False;
  fIncludeLogItems := false;
  fintLogList := TStringList.Create;
  fintLogList.OwnsObjects := true;
end;

destructor TLogStringListProvider.Destroy;
begin
  EnterCriticalSection (CS);
  try
    if Assigned (fintLogList) then
      fintLogList.Free;
  finally
    LeaveCriticalSection (CS);
  end;
  {$IF Defined(MSWINDOWS) OR Defined(DELPHILINUX)}
    DeleteCriticalSection (CS);
  {$ELSE}
    DoneCriticalsection (CS);
  {$ENDIF}
  inherited;
end;

procedure TLogStringListProvider.Init;
begin
  inherited;
end;

procedure TLogStringListProvider.Restart;
begin
  Stop;
  Clear;
  EnterCriticalSection (CS);
  try
    if Assigned (fintLogList) then
      fintLogList.Free;
  finally
    LeaveCriticalSection (CS);
  end;
  Init;
end;

procedure TLogStringListProvider.WriteLog (cLogItem: TLogItem);
begin
  EnterCriticalSection (CS);
  LogList.BeginUpdate;
  try
    if fMaxSize > 0 then
    begin
      while LogList.Count >= fMaxSize do
        LogList.Delete (0);
    end;
    if CustomMsgOutput then
      if IncludeLogItems then
        LogList.AddObject (LogItemToFormat(cLogItem), cLogItem.Clone)
      else
        LogList.Add (LogItemToFormat(cLogItem))
    else
    begin
      if IncludeLogItems then
        LogList.AddObject (LogItemToLine(cLogItem, fShowTimeStamp, fShowEventTypes), cLogItem.Clone)
      else
        LogList.Add (LogItemToLine(cLogItem, fShowTimeStamp, fShowEventTypes));
      if cLogItem.EventType = etHeader then
        LogList.Add (FillStr('-', cLogItem.Msg.Length));
    end;
  finally
    LogList.EndUpdate;
    LeaveCriticalSection (CS);
  end;
end;

procedure TLogStringListProvider.Clear;
begin
  EnterCriticalSection (CS);
  try
    LogList.Clear;
  finally
    LeaveCriticalSection (CS);
  end;
end;

function TLogStringListProvider.GetLogList: TStrings;
begin
  if Assigned (fLogList) then
    Result := fLogList
  else
    Result := fintLogList;
end;

initialization

  GlobalLogStringListProvider := TLogStringListProvider.Create;

finalization

  if Assigned (GlobalLogStringListProvider) and (GlobalLogStringListProvider.RefCount = 0) then
  begin
    GlobalLogStringListProvider.Free;
  end;

end.
