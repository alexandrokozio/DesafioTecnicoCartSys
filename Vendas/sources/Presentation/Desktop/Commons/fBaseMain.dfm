inherited frmBaseMain: TfrmBaseMain
  Caption = 'frmBaseMain'
  Menu = mmuMain
  StyleElements = [seFont, seClient, seBorder]
  OnClose = FormClose
  OnShow = FormShow
  ExplicitWidth = 640
  ExplicitHeight = 480
  TextHeight = 15
  object stbMain: TStatusBar
    Left = 0
    Top = 422
    Width = 624
    Height = 19
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
      end
      item
        Text = 'segunda-feira, 99/99/9999 99:99:99'
        Width = 50
      end>
    ExplicitTop = 414
    ExplicitWidth = 622
  end
  object mmuMain: TMainMenu
    Left = 200
    Top = 72
  end
  object actlstMain: TActionList
    Left = 264
    Top = 72
  end
end
