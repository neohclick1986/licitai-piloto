'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { apiFetch } from '@/lib/api';

type DFDCrewOutput = {
  dfd_id: string;
  versao_revisada: any;
  checklist: Array<{ item: string; status: string; observacao: string }>;
  perguntas_para_demandante: string[];
  citacoes: Array<{ fonte: string; trecho_relevante?: string }>;
  parecer_agente: string;
  ia_usada: boolean;
  tokens_usados: { input: number; output: number } | null;
};

export default function DFDFlowPage() {
  const params = useParams();
  const router = useRouter();
  const processoId = params.id as string;

  const [form, setForm] = useState({
    area_requisitante: '',
    objeto: '',
    justificativa: '',
    quantidade: '',
    unidade_medida: 'unidade',
    valor_estimado: '',
    prazo_entrega_dias: '30',
    destino: '',
    usar_ia: true,
  });

  const [result, setResult] = useState<DFDCrewOutput | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const data = await apiFetch('/dfd/', {
        method: 'POST',
        body: JSON.stringify({
          processo_id: processoId,
          area_requisitante: form.area_requisitante,
          objeto: form.objeto,
          justificativa: form.justificativa,
          quantidade: form.quantidade ? parseFloat(form.quantidade) : null,
          unidade_medida: form.unidade_medida || null,
          valor_estimado: parseFloat(form.valor_estimado),
          prazo_entrega_dias: form.prazo_entrega_dias ? parseInt(form.prazo_entrega_dias) : null,
          destino: form.destino || null,
          usar_ia: form.usar_ia,
        }),
      });
      setResult(data);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  if (result) {
    return <ResultView result={result} processoId={processoId} onReset={() => setResult(null)} />;
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-white border-b border-slate-200 px-6 py-4">
        <Link href={`/processos/${processoId}`} className="text-sm text-slate-600 hover:text-slate-900">
          ← Voltar ao processo
        </Link>
      </header>

      <main className="max-w-3xl mx-auto px-6 py-8">
        <h1 className="text-2xl font-bold text-slate-900 mb-1">DFD</h1>
        <p className="text-slate-600 mb-6">
          Documento de Formalização da Demanda (art. 12, Lei 14.133/2021)
        </p>

        <form onSubmit={onSubmit} className="bg-white border border-slate-200 rounded-lg p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Área requisitante *
            </label>
            <input
              type="text"
              value={form.area_requisitante}
              onChange={(e) => setForm({ ...form, area_requisitante: e.target.value })}
              required
              className="w-full border border-slate-300 rounded-md px-3 py-2"
              placeholder="Ex: Secretaria de Educação"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Objeto *
            </label>
            <textarea
              value={form.objeto}
              onChange={(e) => setForm({ ...form, objeto: e.target.value })}
              required
              minLength={10}
              rows={2}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
              placeholder="Descrição clara e mensurável do que se quer contratar"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Justificativa da necessidade *
            </label>
            <textarea
              value={form.justificativa}
              onChange={(e) => setForm({ ...form, justificativa: e.target.value })}
              required
              minLength={20}
              rows={3}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
              placeholder="Por que esta contratação é necessária? Qual demanda atende?"
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Quantidade</label>
              <input
                type="number"
                step="0.01"
                value={form.quantidade}
                onChange={(e) => setForm({ ...form, quantidade: e.target.value })}
                className="w-full border border-slate-300 rounded-md px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Unidade</label>
              <input
                type="text"
                value={form.unidade_medida}
                onChange={(e) => setForm({ ...form, unidade_medida: e.target.value })}
                className="w-full border border-slate-300 rounded-md px-3 py-2"
                placeholder="un, kg, mês, etc."
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Valor estimado (R$) *</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={form.valor_estimado}
                onChange={(e) => setForm({ ...form, valor_estimado: e.target.value })}
                required
                className="w-full border border-slate-300 rounded-md px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Prazo (dias)</label>
              <input
                type="number"
                value={form.prazo_entrega_dias}
                onChange={(e) => setForm({ ...form, prazo_entrega_dias: e.target.value })}
                className="w-full border border-slate-300 rounded-md px-3 py-2"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Local de entrega</label>
            <input
              type="text"
              value={form.destino}
              onChange={(e) => setForm({ ...form, destino: e.target.value })}
              className="w-full border border-slate-300 rounded-md px-3 py-2"
            />
          </div>

          <div className="flex items-center gap-2 pt-2">
            <input
              type="checkbox"
              id="usar_ia"
              checked={form.usar_ia}
              onChange={(e) => setForm({ ...form, usar_ia: e.target.checked })}
              className="w-4 h-4"
            />
            <label htmlFor="usar_ia" className="text-sm text-slate-700">
              <strong>Revisar com IA</strong> (Crew-DFD analisa e sugere melhorias)
            </label>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-800 rounded-md p-3 text-sm">
              <strong>Erro:</strong> {error}
            </div>
          )}

          <div className="flex justify-end gap-3 pt-2">
            <button
              type="submit"
              disabled={loading}
              className="bg-blue-700 hover:bg-blue-800 text-white px-6 py-2 rounded-md font-medium disabled:opacity-50"
            >
              {loading ? (form.usar_ia ? 'IA analisando…' : 'Salvando…') : 'Criar DFD'}
            </button>
          </div>
        </form>
      </main>
    </div>
  );
}

function ResultView({
  result,
  processoId,
  onReset,
}: {
  result: DFDCrewOutput;
  processoId: string;
  onReset: () => void;
}) {
  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <Link href={`/processos/${processoId}`} className="text-sm text-slate-600 hover:text-slate-900">
          ← Voltar ao processo
        </Link>
        <button
          onClick={onReset}
          className="text-sm text-slate-600 hover:text-slate-900"
        >
          Criar novo DFD
        </button>
      </header>

      <main className="max-w-4xl mx-auto px-6 py-8 space-y-6">
        {result.ia_usada && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-2xl">🤖</span>
              <strong className="text-blue-900">DFD revisado pela Crew-DFD</strong>
            </div>
            <p className="text-sm text-blue-800">{result.parecer_agente}</p>
            {result.tokens_usados && (
              <p className="text-xs text-blue-700 mt-2">
                Tokens: {result.tokens_usados.input} (entrada) + {result.tokens_usados.output} (saída)
              </p>
            )}
          </div>
        )}

        <section className="bg-white border border-slate-200 rounded-lg p-6">
          <h2 className="text-lg font-semibold text-slate-900 mb-4">Versão revisada</h2>
          <pre className="bg-slate-50 border border-slate-200 rounded-md p-3 text-sm overflow-auto">
            {JSON.stringify(result.versao_revisada, null, 2)}
          </pre>
        </section>

        {result.checklist.length > 0 && (
          <section className="bg-white border border-slate-200 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-slate-900 mb-4">
              Checklist de conformidade (art. 12 Lei 14.133/2021)
            </h2>
            <div className="space-y-2">
              {result.checklist.map((c, i) => (
                <div
                  key={i}
                  className="flex items-start gap-3 p-3 border border-slate-100 rounded"
                >
                  <span
                    className={`text-lg ${
                      c.status === '✓'
                        ? 'text-green-600'
                        : c.status === '⚠'
                          ? 'text-amber-600'
                          : 'text-red-600'
                    }`}
                  >
                    {c.status}
                  </span>
                  <div>
                    <p className="font-medium text-slate-900">{c.item}</p>
                    {c.observacao && (
                      <p className="text-sm text-slate-600">{c.observacao}</p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {result.perguntas_para_demandante.length > 0 && (
          <section className="bg-amber-50 border border-amber-200 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-amber-900 mb-4">
              Perguntas para o demandante
            </h2>
            <ul className="list-disc list-inside space-y-1 text-amber-900">
              {result.perguntas_para_demandante.map((q, i) => (
                <li key={i}>{q}</li>
              ))}
            </ul>
          </section>
        )}

        {result.citacoes.length > 0 && (
          <section className="bg-white border border-slate-200 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-slate-900 mb-4">Citações legais</h2>
            <ul className="space-y-2 text-sm">
              {result.citacoes.map((c, i) => (
                <li key={i} className="text-slate-700">
                  <strong>{c.fonte}</strong>
                  {c.trecho_relevante && (
                    <p className="text-slate-600 italic ml-3 mt-1">
                      "{c.trecho_relevante}"
                    </p>
                  )}
                </li>
              ))}
            </ul>
          </section>
        )}
      </main>
    </div>
  );
}
