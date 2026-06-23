'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { apiFetch } from '@/lib/api';

const CATEGORIAS = [
  { value: 'MATERIAL', label: 'Material' },
  { value: 'SERVICO_CONTINUO', label: 'Serviço Contínuo' },
  { value: 'OBRA', label: 'Obra' },
  { value: 'TI', label: 'Tecnologia da Informação' },
  { value: 'OUTROS', label: 'Outros' },
];

export default function NovoProcessoPage() {
  const router = useRouter();
  const [objeto, setObjeto] = useState('');
  const [categoria, setCategoria] = useState('MATERIAL');
  const [valorEstimado, setValorEstimado] = useState('');
  const [areaRequisitante, setAreaRequisitante] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const created = await apiFetch('/processos/', {
        method: 'POST',
        body: JSON.stringify({
          objeto,
          categoria,
          valor_estimado: valorEstimado ? parseFloat(valorEstimado) : null,
          area_requisitante: areaRequisitante || null,
        }),
      });
      router.push(`/processos/${created.id}`);
    } catch (e: any) {
      setError(e.message);
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-white border-b border-slate-200 px-6 py-4">
        <Link href="/" className="text-sm text-slate-600 hover:text-slate-900">
          ← Voltar
        </Link>
      </header>

      <main className="max-w-2xl mx-auto px-6 py-8">
        <h1 className="text-2xl font-bold text-slate-900 mb-6">Novo Processo</h1>

        <form onSubmit={onSubmit} className="bg-white border border-slate-200 rounded-lg p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Objeto
            </label>
            <textarea
              value={objeto}
              onChange={(e) => setObjeto(e.target.value)}
              required
              minLength={10}
              rows={3}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
              placeholder="Ex: Aquisição de papel A4 75g/m² para uso administrativo"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Categoria
            </label>
            <select
              value={categoria}
              onChange={(e) => setCategoria(e.target.value)}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
            >
              {CATEGORIAS.map((c) => (
                <option key={c.value} value={c.value}>
                  {c.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Valor estimado (R$)
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={valorEstimado}
              onChange={(e) => setValorEstimado(e.target.value)}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
              placeholder="0,00"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Área requisitante
            </label>
            <input
              type="text"
              value={areaRequisitante}
              onChange={(e) => setAreaRequisitante(e.target.value)}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
              placeholder="Ex: Secretaria de Administração"
            />
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-800 rounded-md p-3 text-sm">
              {error}
            </div>
          )}

          <div className="flex justify-end gap-3 pt-2">
            <Link
              href="/"
              className="px-4 py-2 text-slate-700 hover:text-slate-900"
            >
              Cancelar
            </Link>
            <button
              type="submit"
              disabled={loading}
              className="bg-blue-700 hover:bg-blue-800 text-white px-6 py-2 rounded-md font-medium disabled:opacity-50"
            >
              {loading ? 'Criando…' : 'Criar Processo'}
            </button>
          </div>
        </form>
      </main>
    </div>
  );
}
