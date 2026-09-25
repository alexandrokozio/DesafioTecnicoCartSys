unit connection.interfaces;

interface

uses
  System.SysUtils,
  Data.DB;

type
  IQuery = interface;

  IDBConnection = interface
  ['{B0AA2C59-5D8C-4E74-A5E6-D99CFB4EED3A}']
    function Connection: TCustomConnection;

    procedure Connect;
    function InTransaction: Boolean;
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
  end;

  IQuery = interface
  ['{5ED41656-2C2B-478D-80B0-92AD81BEDBAA}']
    function Query: TDataSet;

    function SQL(const AValue: string): IQuery;
    function AddParam(const AName: string; AValue: Variant): IQuery;

    function Open: IQuery; overload;
    function ExecSQL: IQuery; overload;

    function Open(const ASql: string): IQuery; overload;
    function ExecSQL(const ASql: string): IQuery; overload;
  end;

  IDBConnectionFactory = interface
  ['{229128EF-B6A3-4086-897A-D0426FC0CD73}']
    function Connection: IDBConnection;
    function Query: IQuery;
  end;

  /// <summary>
  /// Delimita uma transação de negócio. Os serviços de aplicação não conhecem
  /// StartTransaction/Commit/Rollback: apenas descrevem o que deve ser atômico.
  /// Chamadas aninhadas participam da transação já aberta.
  /// </summary>
  IUnitOfWork = interface
  ['{6579A3C0-7139-4D4A-819C-C7CDECC99FC1}']
    procedure Executar(const AOperacao: TProc);
  end;

implementation

end.
