using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Financeiro.Infrastructure.Persistence.Migrations
{  
    public partial class Inicial : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "OUTBOX_NOTIFICACAO",
                columns: table => new
                {
                    ID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TIPO = table.Column<string>(type: "varchar(30)", unicode: false, maxLength: 30, nullable: false),
                    VENDA_ID = table.Column<int>(type: "int", nullable: false),
                    CONTEUDO = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    STATUS = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    TENTATIVAS = table.Column<int>(type: "int", nullable: false),
                    PROXIMA_TENTATIVA = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ULTIMO_ERRO = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    DATA_CRIACAO = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DATA_ENVIO = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OUTBOX_NOTIFICACAO", x => x.ID);
                });

            migrationBuilder.CreateTable(
                name: "VENDA_FINANCEIRA",
                columns: table => new
                {
                    ID = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    VENDA_ID = table.Column<int>(type: "int", nullable: false),
                    DATA_VENDA = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CLIENTE_ID = table.Column<int>(type: "int", nullable: false),
                    CLIENTE_NOME = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    CLIENTE_DOCUMENTO = table.Column<string>(type: "nvarchar(18)", maxLength: 18, nullable: false),
                    CLIENTE_EMAIL = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    STATUS = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    VALOR_TOTAL = table.Column<decimal>(type: "decimal(15,2)", precision: 15, scale: 2, nullable: false),
                    DATA_RECEBIMENTO = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DATA_ATUALIZACAO = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DATA_QUITACAO = table.Column<DateTime>(type: "datetime2", nullable: true),
                    FORMA_PAGAMENTO = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    DATA_CANCELAMENTO = table.Column<DateTime>(type: "datetime2", nullable: true),
                    MOTIVO_CANCELAMENTO = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    ORIGEM_CANCELAMENTO = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: true),
                    VERSAO = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VENDA_FINANCEIRA", x => x.ID);
                });

            migrationBuilder.CreateTable(
                name: "VENDA_FINANCEIRA_ITEM",
                columns: table => new
                {
                    ID = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PRODUTO_ID = table.Column<int>(type: "int", nullable: false),
                    DESCRICAO = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    QUANTIDADE = table.Column<int>(type: "int", nullable: false),
                    PRECO_UNITARIO = table.Column<decimal>(type: "decimal(15,2)", precision: 15, scale: 2, nullable: false),
                    VALOR_TOTAL = table.Column<decimal>(type: "decimal(15,2)", precision: 15, scale: 2, nullable: false),
                    VENDA_FINANCEIRA_ID = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VENDA_FINANCEIRA_ITEM", x => x.ID);
                    table.ForeignKey(
                        name: "FK_VENDA_FINANCEIRA_ITEM_VENDA_FINANCEIRA_VENDA_FINANCEIRA_ID",
                        column: x => x.VENDA_FINANCEIRA_ID,
                        principalTable: "VENDA_FINANCEIRA",
                        principalColumn: "ID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OUTBOX_NOTIFICACAO_PENDENTES",
                table: "OUTBOX_NOTIFICACAO",
                columns: new[] { "STATUS", "PROXIMA_TENTATIVA" });

            migrationBuilder.CreateIndex(
                name: "IX_OUTBOX_NOTIFICACAO_VENDA",
                table: "OUTBOX_NOTIFICACAO",
                column: "VENDA_ID");

            migrationBuilder.CreateIndex(
                name: "IX_VENDA_FINANCEIRA_DATA_VENDA",
                table: "VENDA_FINANCEIRA",
                column: "DATA_VENDA");

            migrationBuilder.CreateIndex(
                name: "IX_VENDA_FINANCEIRA_STATUS",
                table: "VENDA_FINANCEIRA",
                column: "STATUS");

            migrationBuilder.CreateIndex(
                name: "UQ_VENDA_FINANCEIRA_VENDA_ID",
                table: "VENDA_FINANCEIRA",
                column: "VENDA_ID",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VENDA_FINANCEIRA_ITEM_VENDA_FINANCEIRA_ID",
                table: "VENDA_FINANCEIRA_ITEM",
                column: "VENDA_FINANCEIRA_ID");
        }
        
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OUTBOX_NOTIFICACAO");

            migrationBuilder.DropTable(
                name: "VENDA_FINANCEIRA_ITEM");

            migrationBuilder.DropTable(
                name: "VENDA_FINANCEIRA");
        }
    }
}
