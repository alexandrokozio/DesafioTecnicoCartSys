using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Financeiro.Infrastructure.Persistence;

internal sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<FinanceiroDbContext>
{
    public FinanceiroDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<FinanceiroDbContext>()
            .UseSqlServer(@"Server=(localdb)\MSSQLLocalDB;Database=CartsysFinanceiro;Trusted_Connection=True;TrustServerCertificate=True")
            .Options;

        return new FinanceiroDbContext(options, TimeProvider.System);
    }
}
