inherited frmMain: TfrmMain
  Caption = 'frmMain'
  ClientHeight = 436
  WindowState = wsMaximized
  StyleElements = [seFont, seClient, seBorder]
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  ExplicitLeft = 3
  ExplicitTop = 3
  ExplicitHeight = 475
  TextHeight = 15
  inherited stbMain: TStatusBar
    Top = 417
    Panels = <
      item
        Text = 'Usu'#225'rio:'
        Width = 60
      end
      item
        Text = 'ADMIN'
        Width = 100
      end
      item
        Text = 'Perfil:'
        Width = 50
      end
      item
        Text = 'ADMIN'
        Width = 100
      end>
    ExplicitTop = 409
  end
  object pnlWorkArea: TPanel [1]
    Left = 102
    Top = 0
    Width = 522
    Height = 417
    Align = alClient
    BevelOuter = bvNone
    Caption = 'pnlWorkArea'
    Color = clGray
    ParentBackground = False
    ShowCaption = False
    TabOrder = 1
    ExplicitWidth = 520
    ExplicitHeight = 409
  end
  object pnlBotoes: TPanel [2]
    Left = 0
    Top = 0
    Width = 102
    Height = 417
    Align = alLeft
    BevelOuter = bvNone
    BorderWidth = 10
    Caption = 'pnlBotoes'
    Color = clSilver
    ParentBackground = False
    ShowCaption = False
    TabOrder = 2
    ExplicitHeight = 409
    object btnCadProdutos: TButton
      Left = 10
      Top = 60
      Width = 82
      Height = 50
      Action = actCadProdutos
      Align = alTop
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      WordWrap = True
    end
    object btnCadClientes: TButton
      Left = 10
      Top = 10
      Width = 82
      Height = 50
      Action = actCadClientes
      Align = alTop
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      WordWrap = True
    end
    object btnSair: TButton
      Left = 10
      Top = 160
      Width = 82
      Height = 50
      Action = actSair
      Align = alTop
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      TabOrder = 3
      WordWrap = True
    end
    object btnCadVendas: TButton
      Left = 10
      Top = 110
      Width = 82
      Height = 50
      Action = actCadVendas
      Align = alTop
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      TabOrder = 2
      WordWrap = True
    end
  end
  inherited actlstMain: TActionList
    Left = 272
    object actSair: TAction
      Caption = '&Sair [->'
      OnExecute = actSairExecute
    end
    object actCadClientes: TAction
      Category = 'Cadastros'
      Caption = '&Clientes'
      OnExecute = actCadClientesExecute
    end
    object actCadProdutos: TAction
      Category = 'Cadastros'
      Caption = '&Produtos'
      OnExecute = actCadProdutosExecute
    end
    object actCadVendas: TAction
      Category = 'Cadastros'
      Caption = '&Vendas'
      OnExecute = actCadVendasExecute
    end
  end
end
