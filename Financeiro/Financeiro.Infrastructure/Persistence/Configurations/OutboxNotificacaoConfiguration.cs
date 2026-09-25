using Financeiro.Infrastructure.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Financeiro.Infrastructure.Persistence.Configurations;

internal sealed class OutboxNotificacaoConfiguration : IEntityTypeConfiguration<OutboxNotificacao>
{
    public void Configure(EntityTypeBuilder<OutboxNotificacao> builder)
    {
        builder.ToTable("OUTBOX_NOTIFICACAO");

        builder.HasKey(n => n.Id);
        builder.Property(n => n.Id).HasColumnName("ID");
        builder.Property(n => n.Tipo).HasColumnName("TIPO").HasConversion<string>().HasMaxLength(30).IsUnicode(false);
        builder.Property(n => n.VendaId).HasColumnName("VENDA_ID");
        builder.Property(n => n.Conteudo).HasColumnName("CONTEUDO");
        builder.Property(n => n.Status).HasColumnName("STATUS").HasConversion<string>().HasMaxLength(20).IsUnicode(false);
        builder.Property(n => n.Tentativas).HasColumnName("TENTATIVAS");
        builder.Property(n => n.ProximaTentativa).HasColumnName("PROXIMA_TENTATIVA");
        builder.Property(n => n.UltimoErro).HasColumnName("ULTIMO_ERRO").HasMaxLength(1000);
        builder.Property(n => n.DataCriacao).HasColumnName("DATA_CRIACAO");
        builder.Property(n => n.DataEnvio).HasColumnName("DATA_ENVIO");

        builder.HasIndex(n => new { n.Status, n.ProximaTentativa }).HasDatabaseName("IX_OUTBOX_NOTIFICACAO_PENDENTES");
        builder.HasIndex(n => n.VendaId).HasDatabaseName("IX_OUTBOX_NOTIFICACAO_VENDA");
    }
}
