using Financeiro.Domain.Vendas;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Financeiro.Infrastructure.Persistence.Configurations;

internal sealed class VendaFinanceiraConfiguration : IEntityTypeConfiguration<VendaFinanceira>
{
    public void Configure(EntityTypeBuilder<VendaFinanceira> builder)
    {
        builder.ToTable("VENDA_FINANCEIRA");

        builder.HasKey(v => v.Id);
        builder.Property(v => v.Id).HasColumnName("ID");

        builder.Property(v => v.VendaId).HasColumnName("VENDA_ID");
        builder.HasIndex(v => v.VendaId).IsUnique().HasDatabaseName("UQ_VENDA_FINANCEIRA_VENDA_ID");

        builder.Property(v => v.DataVenda).HasColumnName("DATA_VENDA");
        builder.Property(v => v.Status).HasColumnName("STATUS")
            .HasConversion<string>().HasMaxLength(20).IsUnicode(false);
        builder.Property(v => v.ValorTotal).HasColumnName("VALOR_TOTAL").HasPrecision(15, 2);
        builder.Property(v => v.DataRecebimento).HasColumnName("DATA_RECEBIMENTO");
        builder.Property(v => v.DataAtualizacao).HasColumnName("DATA_ATUALIZACAO");
        builder.Property(v => v.DataQuitacao).HasColumnName("DATA_QUITACAO");
        builder.Property(v => v.FormaPagamento).HasColumnName("FORMA_PAGAMENTO")
            .HasMaxLength(VendaFinanceira.TamanhoFormaPagamento);
        builder.Property(v => v.DataCancelamento).HasColumnName("DATA_CANCELAMENTO");
        builder.Property(v => v.MotivoCancelamento).HasColumnName("MOTIVO_CANCELAMENTO")
            .HasMaxLength(VendaFinanceira.TamanhoMotivo);
        builder.Property(v => v.OrigemCancelamento).HasColumnName("ORIGEM_CANCELAMENTO")
            .HasConversion<string>().HasMaxLength(20).IsUnicode(false);

        builder.Property<Guid>(FinanceiroDbContext.PropriedadeVersao).HasColumnName("VERSAO").IsConcurrencyToken();

        builder.OwnsOne(v => v.Cliente, cliente =>
        {
            cliente.Property(c => c.ClienteId).HasColumnName("CLIENTE_ID");
            cliente.Property(c => c.Nome).HasColumnName("CLIENTE_NOME").HasMaxLength(ClienteVenda.TamanhoNome);
            cliente.Property(c => c.Documento).HasColumnName("CLIENTE_DOCUMENTO").HasMaxLength(ClienteVenda.TamanhoDocumento);
            cliente.Property(c => c.Email).HasColumnName("CLIENTE_EMAIL").HasMaxLength(ClienteVenda.TamanhoEmail);
        });
        builder.Navigation(v => v.Cliente).IsRequired();

        builder.HasMany(v => v.Itens)
            .WithOne()
            .HasForeignKey("VendaFinanceiraId")
            .OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(v => v.Itens).UsePropertyAccessMode(PropertyAccessMode.Field);

        builder.Ignore(v => v.EventosDeDominio);

        builder.HasIndex(v => v.Status).HasDatabaseName("IX_VENDA_FINANCEIRA_STATUS");
        builder.HasIndex(v => v.DataVenda).HasDatabaseName("IX_VENDA_FINANCEIRA_DATA_VENDA");
    }
}

internal sealed class VendaFinanceiraItemConfiguration : IEntityTypeConfiguration<VendaFinanceiraItem>
{
    public void Configure(EntityTypeBuilder<VendaFinanceiraItem> builder)
    {
        builder.ToTable("VENDA_FINANCEIRA_ITEM");

        builder.HasKey(i => i.Id);
        builder.Property(i => i.Id).HasColumnName("ID");
        builder.Property<int>("VendaFinanceiraId").HasColumnName("VENDA_FINANCEIRA_ID");

        builder.Property(i => i.ProdutoId).HasColumnName("PRODUTO_ID");
        builder.Property(i => i.Descricao).HasColumnName("DESCRICAO").HasMaxLength(VendaFinanceiraItem.TamanhoDescricao);
        builder.Property(i => i.Quantidade).HasColumnName("QUANTIDADE");
        builder.Property(i => i.PrecoUnitario).HasColumnName("PRECO_UNITARIO").HasPrecision(15, 2);
        builder.Property(i => i.ValorTotal).HasColumnName("VALOR_TOTAL").HasPrecision(15, 2);

        builder.Ignore(i => i.EventosDeDominio);
    }
}
