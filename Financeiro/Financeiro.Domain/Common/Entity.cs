namespace Financeiro.Domain.Common;

public abstract class Entity
{
    private readonly List<IDomainEvent> _eventos = [];

    public int Id { get; protected set; }

    public IReadOnlyCollection<IDomainEvent> EventosDeDominio => _eventos.AsReadOnly();

    protected void RegistrarEvento(IDomainEvent evento) => _eventos.Add(evento);

    public void LimparEventos() => _eventos.Clear();
}
