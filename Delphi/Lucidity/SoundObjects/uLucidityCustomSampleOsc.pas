{
  TCustomSampleOsc is the base class for all Lucidity sample oscillator classes.
}

unit uLucidityCustomSampleOsc;

interface

uses
  Lucidity.Types,
  Lucidity.Interfaces,
  VamLib.MoreTypes, Lucidity.SampleMap, uConstants, eeSampleFloat,
  uLucidityClock;

type
  TCustomSampleOsc = class
  private
    fSampleRate: single;
    fTempo: single;
  protected
    OneOverSampleRate : double; //for optimisation purposes.
    VoiceModPoints : PVoiceModulationPoints;
    VoiceClockManager : TLucidityVoiceClockManager;

    ParValueData : PModulatedPars;     // Raw parameter values. The values are identical for all voices in the voice group.
    ParModData   : PParModulationData; // stores the summed modulation input for each parameter. (Most parameters will be zero)

    procedure SetSampleRate(const Value: single); virtual;

    procedure Event_UpdateSampleBounds(const Sender:TObject; const aSampleRegion:IRegion; const SampleBounds:PSampleOsc_SampleBounds);
  public
    constructor Create(const aVoiceModPoints : PVoiceModulationPoints; const aVoiceClockManager : TLucidityVoiceClockManager); virtual;
    destructor Destroy; override;

    procedure Init(const aPars : PModulatedPars; const aModData : PParModulationData);

    property SampleRate : single read fSampleRate write SetSampleRate;
    property Tempo      : single read fTempo      write fTempo; //bpm
  end;

implementation

uses
  Lucidity.PluginParameters,
  VamLib.Utils;

{ TCustomSampleOsc }

constructor TCustomSampleOsc.Create(const aVoiceModPoints: PVoiceModulationPoints; const aVoiceClockManager : TLucidityVoiceClockManager);
begin
  VoiceModPoints := aVoiceModPoints;
  VoiceClockManager := aVoiceClockManager;
end;

destructor TCustomSampleOsc.Destroy;
begin

  inherited;
end;


procedure TCustomSampleOsc.SetSampleRate(const Value: single);
begin
  fSampleRate := Value;
  OneOverSampleRate := 1 / fSampleRate;
end;

procedure TCustomSampleOsc.Event_UpdateSampleBounds(const Sender: TObject; const aSampleRegion: IRegion; const SampleBounds: PSampleOsc_SampleBounds);
var
  RegionProps : PRegionProperties;
  SampleX1 : single;
  SampleX2 : single;
  RegionLoopStart, RegionLoopEnd : integer;
  LoopX1, LoopX2 : single;
  SampleStart, SampleEnd : integer;
  LoopStart, LoopEnd : integer;
  SampleFrames : integer;
  PrevIndex, NextIndex, NearestIndex, FarIndex : integer;
  SampleStartMod, SampleEndMod, LoopStartMod, LoopEndMod : single;

  Index1 : integer;
  Index2 : integer;
  Index3 : integer;
  Index4 : integer;
begin
  RegionProps := aSampleRegion.GetProperties;
  SampleFrames := aSampleRegion.GetSample^.Properties.SampleFrames;

  Index1 := GetModParIndex(TPluginParameter.SampleStart);
  Index2 := GetModParIndex(TPluginParameter.SampleEnd);
  Index3 := GetModParIndex(TPluginParameter.LoopStart);
  Index4 := GetModParIndex(TPluginParameter.LoopEnd);

  //SampleStartMod := ParModData^.Raw[Index1];
  //SampleEndMod   := ParModData^.Raw[Index2];
  //LoopStartMod   := ParModData^.Raw[Index3];
  //LoopEndMod     := ParModData^.Raw[Index4];

  SampleStartMod := ParModData^.SummedModulation[Index1];
  SampleEndMod   := ParModData^.SummedModulation[Index2];
  LoopStartMod   := ParModData^.SummedModulation[Index3];
  LoopEndMod     := ParModData^.SummedModulation[Index4];

  if RegionProps^.SampleStart < RegionProps^.SampleEnd then
  begin
    SampleX1 := RegionProps^.SampleStart + (SampleStartMod * SampleFrames);
    SampleX2 := RegionProps^.SampleEnd   + (SampleEndMod   * SampleFrames);
  end else
  begin
    SampleX1 := RegionProps^.SampleEnd   + (SampleEndMod   * SampleFrames);
    SampleX2 := RegionProps^.SampleStart + (SampleStartMod * SampleFrames);
  end;

  RegionProps^.GetRegionLoopPoints(RegionLoopStart, RegionLoopEnd);
  if RegionLoopStart = -1 then RegionLoopStart := 0;
  if RegionLoopEnd   = -1 then RegionLoopEnd   := SampleFrames-1;

  // TODO:HIGH I don't think this conditional assignment is needed.
  // The modulation can reverse the positions of loop start and loop end
  // anyway. The loop start/end markers must be getting checked again
  // later.
  if RegionLoopStart < RegionLoopEnd then
  begin
    LoopX1 := RegionLoopStart + (LoopStartMod * SampleFrames);
    LoopX2 := RegionLoopEnd   + (LoopEndMod   * SampleFrames);
  end else
  begin
    LoopX1 := RegionLoopEnd   + (LoopEndMod   * SampleFrames);
    LoopX2 := RegionLoopStart + (LoopStartMod * SampleFrames);
  end;

  SampleStart := round(SampleX1);
  SampleEnd   := round(SampleX2);

  LoopStart := round(LoopX1);
  LoopEnd   := round(LoopX2);

  // TODO:MED Make this "force to zero crossing optional"
  if (aSampleRegion.GetDbLevelAt(SampleStart) > -96) then
  begin
    aSampleRegion.GetZeroCrossings.FindNearestZeroCrossingIndex(SampleStart, NextIndex, PrevIndex, NearestIndex, FarIndex);
    SampleStart := NearestIndex;
  end;

  if (aSampleRegion.GetDbLevelAt(SampleEnd) > -96) then
  begin
    aSampleRegion.GetZeroCrossings.FindNearestZeroCrossingIndex(SampleEnd, NextIndex, PrevIndex, NearestIndex, FarIndex);
    if SampleStart <> NearestIndex
      then SampleEnd := NearestIndex
      else SampleEnd := FarIndex;
  end;

  if (aSampleRegion.GetDbLevelAt(LoopStart) > -96) then
  begin
    aSampleRegion.GetZeroCrossings.FindNearestZeroCrossingIndex(LoopStart, NextIndex, PrevIndex, NearestIndex, FarIndex);
    LoopStart := NearestIndex;
  end;

  if (aSampleRegion.GetDbLevelAt(LoopEnd) > -96) then
  begin
    aSampleRegion.GetZeroCrossings.FindNearestZeroCrossingIndex(LoopEnd, NextIndex, PrevIndex, NearestIndex, FarIndex);
    if LoopStart <> NearestIndex
      then LoopEnd := NearestIndex
      else LoopEnd := FarIndex;
  end;

  if SampleEnd < SampleStart then SwapValues(SampleStart, SampleEnd);
  if LoopEnd   < LoopStart   then SwapValues(LoopStart, LoopEnd);

  if LoopStart < SampleStart then LoopStart := SampleStart;
  if LoopEnd   > SampleEnd   then LoopEnd   := SampleEnd;

  SampleStart := Clamp(SampleStart, 0, SampleFrames-1);
  SampleEnd   := Clamp(SampleEnd,   0, SampleFrames-1);
  LoopStart   := Clamp(LoopStart,   0, SampleFrames-1);
  LoopEnd     := Clamp(LoopEnd,     0, SampleFrames-1);

  SampleBounds^.AbsoluteSampleStart := 0;
  SampleBounds^.AbsoluteSampleEnd   := SampleFrames-1;
  SampleBounds^.SampleStart := SampleStart;
  SampleBounds^.SampleEnd   := SampleEnd;
  SampleBounds^.LoopStart   := LoopStart;
  SampleBounds^.LoopEnd     := LoopEnd;
end;

procedure TCustomSampleOsc.Init(const aPars: PModulatedPars; const aModData: PParModulationData);
begin
  ParValueData := aPars;
  ParModData   := aModData;
end;

end.

