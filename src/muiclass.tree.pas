unit MUIClass.Tree;
{$mode ObjFPC}{$H+}
interface

uses
  Classes, SysUtils, fgl, mui, AGraphics, Math,
  MUIClass.Base, MUIClass.Group, MUIClass.Gadget, MUIClass.DrawPanel;

type
  TMUITreeNode = class;

  TMUITreeNodeList = specialize TFPGObjectList<TMUITreeNode>;

  { TMUITreeNode }

  TMUITreeNode = class
  private
    FExpanded: Boolean;
    FParentNode: TMUITreeNode;
    TextRect: TRect;
    ImgRect: TRect;
    FUpdating: Boolean;
    function GetHasChilds: Boolean;
    procedure SetExpanded(AValue: Boolean);
  public
    Name: string;
    Data: Pointer;
    Childs: TMUITreeNodeList;
    constructor Create(AParentNode: TMUITreeNode); virtual;
    destructor Destroy; override;

    property HasChilds: Boolean read GetHasChilds;
    property Expanded: Boolean read FExpanded write SetExpanded;
    property ParentNode: TMUITreeNode read FParentNode;
  end;



  { TMUICustomTree }

  TMUICustomTree = class(TMUIGroup)
  private
    FNormFont: PTextFont;
    FOnNodeClick: TNotifyEvent;
    FOnNodeDblClick: TNotifyEvent;
    FOnSelectedNode: TNotifyEvent;
    FSelectedNode: TMUITreeNode;
    TH: LongWord;
    FDrawPanel: TMUIDrawPanel;
    FScroller: TMUIScrollbar;
    FUpdating: Boolean;
    procedure DrawMe(Sender: TObject; Rp: PRastPort; DrawRect: TRect);
    procedure FirstChange(Sender: TObject);
    procedure KeyDown(Sender: TObject; Shift: TMUIShiftState; Code: Word; Key: Char; var EatEvent: Boolean);
    procedure MouseDblEvent(Sender: TObject; MouseBtn: TMUIMouseBtn; X, Y: Integer; var EatEvent: Boolean);
    procedure MouseDownEvent(Sender: TObject; MouseBtn: TMUIMouseBtn; X, Y: Integer; var EatEvent: Boolean);
    procedure SetSelectedNode(AValue: TMUITreeNode);
  public
    AllNodes: TMUITreeNodeList;
    Nodes: TMUITreeNodeList;

    function AddNode(ParentNode: TMUITreeNode; AName: string; Data: Pointer = nil): TMUITreeNode;
    function DeleteNode(ANode: TMUITreeNode): Boolean;

    constructor Create; override;
    destructor Destroy; override;

    procedure Redraw;

    procedure BeginUpdate;
    procedure EndUpdate;

    property SelectedNode: TMUITreeNode read FSelectedNode write SetSelectedNode;
    property OnSelectedNode: TNotifyEvent read FOnSelectedNode write FOnSelectedNode;
    property OnNodeClick: TNotifyEvent read FOnNodeClick write FOnNodeClick;
    property OnNodeDblClick: TNotifyEvent read FOnNodeDblClick write FOnNodeDblClick;
  end;


implementation

{ TMUICustomTree }

procedure TMUICustomTree.DrawMe(Sender: TObject; Rp: PRastPort; DrawRect: TRect);
var
  TE: TTextExtent;
  y, YStart: Integer;
  OldFont: pTextFont;

  procedure DrawChilds(LocalIndent: Integer; NodeList: TMUITreeNodeList);
  var
    i: Integer;
    LastY: Integer;
    Node: TMUITreeNode;
    LastHadChild: Boolean;
  begin
    LastHadChild := False;
    LastY := (y - TH) + 2;
    for i := 0 to NodeList.Count - 1 do
    begin
      Node := NodeList[i];
      if LastHadChild then
        GFXMove(RP, DrawRect.Left + LocalIndent - 15, DrawRect.Top + LastY + 3)
      else
        GFXMove(RP, DrawRect.Left + LocalIndent - 15, DrawRect.Top + LastY);
      LastY := y - TH div 4 - 1;
      Draw(RP,DrawRect.Left + LocalIndent - 15, DrawRect.Top + LastY);
      Draw(RP,DrawRect.Left + LocalIndent - 5, DrawRect.Top + LastY);
      GFXMove(RP, DrawRect.Left + LocalIndent, DrawRect.Top + y);
      if Node = FSelectedNode then
        SetABPenDrMd(rp, 2, 3, Jam2)
      else
        SetABPenDrMd(rp, 1, 3, Jam1);
      GfxText(rp, PChar(Node.Name), Length(Node.Name));
      SetABPenDrMd(rp, 1, 3, Jam1);
      Node.TextRect := Rect(LocalIndent, y - TH, LocalIndent + TextLength(rp, PChar(Node.Name), Length(Node.Name)), y);
      y := y + TH;
      Node.ImgRect := TRect.Empty;
      LastHadChild := Node.HasChilds;
      if Node.HasChilds then
      begin
        Node.ImgRect := Node.TextRect;
        Node.ImgRect := Rect(LocalIndent - 19, Node.TextRect.CenterPoint.Y - 2, LocalIndent - 11, Node.TextRect.CenterPoint.Y + 6);
        SetAPen(RP, 1);
        RectFill(RP, DrawRect.Left + Node.ImgRect.Left, DrawRect.Top + Node.ImgRect.Top, DrawRect.Left + Node.ImgRect.Right, DrawRect.Top + Node.ImgRect.Bottom);
        SetAPen(RP, 0);
        RectFill(RP, DrawRect.Left + Node.ImgRect.Left + 1, DrawRect.Top + Node.ImgRect.Top + 1, DrawRect.Left + Node.ImgRect.Right - 1, DrawRect.Top + Node.ImgRect.Bottom - 1);
        SetAPen(RP, 1);
        GfxMove(RP, DrawRect.Left + Node.ImgRect.Left + 2, DrawRect.Top + Node.ImgRect.CenterPoint.Y);
        Draw(RP, DrawRect.Left + Node.ImgRect.Right - 2, DrawRect.Top + Node.ImgRect.CenterPoint.Y);
        if Node.Expanded then
        begin
          DrawChilds(LocalIndent + 20, Node.Childs);
        end
        else
        begin
          GfxMove(RP, DrawRect.Left + Node.ImgRect.CenterPoint.X, DrawRect.Top + Node.ImgRect.Top + 2);
          Draw(RP, DrawRect.Left + Node.ImgRect.CenterPoint.X, DrawRect.Top + Node.ImgRect.Bottom - 2);
        end;
      end;
    end;
  end;

begin
  if not Assigned(FNormFont) then
    FNormFont := OpenMUIFont(fkNormal);
  OldFont := RP^.Font;
  RP^.Font := FNormFont;
  SetABPenDrMd(rp, 1, 3, Jam1);
  TextExtent(RP, 'Wp', 2, @TE);
  TH := Round(TE.te_Height * 1.2);
  YStart := FScroller.First;
  Y := TH - YStart;
  DrawChilds(20, Nodes);
  FScroller.Entries := y + YStart;
  FScroller.Visible := DrawRect.Height;
  RP^.Font := OldFont;
end;

procedure TMUICustomTree.FirstChange(Sender: TObject);
begin
  Redraw;
end;

procedure TMUICustomTree.KeyDown(Sender: TObject; Shift: TMUIShiftState; Code: Word; Key: Char; var EatEvent: Boolean);
var
  Idx: Integer;
begin
  EatEvent := True;
  //writeln(' Code =  ', Code);
  case code of
    76: begin // up
      Idx := AllNodes.IndexOf(FSelectedNode);
      if Idx > 0 then
        SelectedNode := AllNodes[Idx - 1];
    end;
    77: begin // down
      Idx := AllNodes.IndexOf(FSelectedNode);
      if (Idx >= 0) and (Idx < AllNodes.Count - 1) then
        SelectedNode := AllNodes[Idx + 1];
    end;
    78: begin // Right
      if Assigned(FSelectedNode) and FSelectedNode.HasChilds and not FSelectedNode.Expanded then
      begin
        FSelectedNode.Expanded := True;
        Redraw;
      end;
    end;
    79: begin // left
      if Assigned(FSelectedNode) and FSelectedNode.HasChilds and FSelectedNode.Expanded then
      begin
        FSelectedNode.Expanded := False;
        Redraw;
      end;
    end;
  end;
  //if Code =
end;

procedure TMUICustomTree.MouseDblEvent(Sender: TObject; MouseBtn: TMUIMouseBtn; X, Y: Integer; var EatEvent: Boolean);
begin
  if Assigned(FSelectedNode) and Assigned(FOnNodeDblClick) then
  begin
    if FSelectedNode.TextRect.Contains(Point(x,y)) then
      FOnNodeDblClick(Self);
  end;
end;

procedure TMUICustomTree.MouseDownEvent(Sender: TObject; MouseBtn: TMUIMouseBtn; X, Y: Integer; var EatEvent: Boolean);
var
  Found: Boolean;

  procedure CheckClick(NodeList: TMUITreeNodeList);
  var
    i: Integer;
    Node: TMUITreeNode;
  begin
    for i := 0 to NodeList.Count - 1 do
    begin
      Node := NodeList[i];
      if Node.HasChilds and Node.ImgRect.Contains(Point(x,y)) then
      begin
        Node.Expanded := not Node.Expanded;
        Found := True;
        Exit;
      end;
      //
      if Node.TextRect.Contains(Point(x,y)) then
      begin
        SelectedNode := Node;
        if Assigned(FOnNodeClick) then
          FOnNodeClick(Self);
        Found := True;
        Exit;
      end;
      //
      if Node.Expanded then
        CheckClick(Node.Childs);
      if Found then
        Exit;
    end;
  end;
begin
  Found := False;
  CheckClick(Nodes);
  Redraw;
end;

procedure TMUICustomTree.SetSelectedNode(AValue: TMUITreeNode);
begin
  if FSelectedNode = AValue then Exit;
  FSelectedNode := AValue;

  if Assigned(FSelectedNode) then
  begin
    if FSelectedNode.TextRect.Top < 0 then
      FScroller.First := FScroller.First + FSelectedNode.TextRect.Top
    else
    if FSelectedNode.TextRect.Bottom > FDrawPanel.Height then
      FScroller.First := FScroller.First + FSelectedNode.TextRect.Top - (FDrawPanel.Height - 2 * TH)
  end;
  if Assigned(FOnSelectedNode) then
      FOnSelectedNode(Self);
  Redraw;
end;

function TMUICustomTree.AddNode(ParentNode: TMUITreeNode; AName: string; Data: Pointer): TMUITreeNode;
var
  NNode: TMUITreeNode;
begin
  NNode := TMUITreeNode.Create(ParentNode);
  NNode.Name := AName;
  NNode.Data := Data;
  if Assigned(ParentNode) then
  begin
    ParentNode.Childs.Add(NNode);
  end
  else
  begin
    Nodes.Add(NNode);
  end;
  AllNodes.Add(NNode);
  Result := NNode;
  Redraw;
end;

function TMUICustomTree.DeleteNode(ANode: TMUITreeNode): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  Idx := AllNodes.IndexOf(ANode);
  if Idx < 0 then
    Exit;
  if Assigned(ANode.ParentNode) then
    ANode.ParentNode.Childs.Remove(ANode);
  if FSelectedNode = ANode then
    SelectedNode := nil;
  AllNodes.Delete(Idx);
  Result := True;
  Redraw;
end;

constructor TMUICustomTree.Create;
begin
  inherited Create;
  FUpdating := False;
  FSelectedNode := nil;
  Nodes := TMUITreeNodeList.Create(False);
  AllNodes := TMUITreeNodeList.Create(True);
  Horiz := True;
  Frame := MUIV_Frame_None;
  FDrawPanel := TMUIDrawPanel.Create;
  with FDrawPanel do
  begin
    Frame := MUIV_Frame_None;
    MinHeight := 100;
    MinWidth := 100;
    DefHeight := 200;
    DefWidth := 200;
    MaxHeight := MUI_MAXMAX;
    MaxWidth := MUI_MAXMAX;
    FillArea := True;
    OnDrawObject  := @DrawMe;
    OnMouseDown  := @MouseDownEvent;
    OnDblClick  := @MouseDblEvent;
    OnKeyDown  := @KeyDown;
    Parent := Self;
  end;
  FScroller := TMUIScrollbar.Create;
  with FScroller do
  begin
    Frame := MUIV_Frame_None;
    Horiz := False;
    Parent := Self;
    OnFirstChange  := @FirstChange;
  end;

end;

destructor TMUICustomTree.Destroy;
begin
  Nodes.Free;
  AllNodes.Free;
  inherited Destroy;
end;

procedure TMUICustomTree.Redraw;
begin
  if not FUpdating then
    FDrawPanel.RedrawObject;
end;

procedure TMUICustomTree.BeginUpdate;
begin
  FUpdating := True;
end;

procedure TMUICustomTree.EndUpdate;
begin
  FUpdating := False;
  Redraw;
end;


{ TMUITreeNode }

function TMUITreeNode.GetHasChilds: Boolean;
begin
  Result := Childs.Count > 0;
end;

procedure TMUITreeNode.SetExpanded(AValue: Boolean);
begin
  if FExpanded = AValue then
    Exit;
  FExpanded := AValue;
end;

constructor TMUITreeNode.Create(AParentNode: TMUITreeNode);
begin
  Childs := TMUITreeNodeList.Create(False);
  FExpanded := True;
  FParentNode := AParentNode;
end;

destructor TMUITreeNode.Destroy;
begin
  Childs.Free;
  inherited Destroy;
end;

end.
