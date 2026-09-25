object wmApi: TwmApi
  OnCreate = WebModuleCreate
  OnDestroy = WebModuleDestroy
  Actions = <
    item
      Default = True
      Name = 'actDespachar'
      PathInfo = '/'
      OnAction = DespacharAction
    end>
  Height = 288
  Width = 519
  PixelsPerInch = 120
end
