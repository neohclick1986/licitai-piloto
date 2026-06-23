'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiFetch } from '@/lib/api';

type Processo = {
  id: string;
  numero_ano: string | null;
  objeto: string;
  status: string;
  valor_estimado: number | null;
  tem_dfd: boolean;
  tem_etp: boolean;
  tem_tr: boolean;
  tem_edital: boolean;
  tem_parecer: boolean;
  tem_contrato: boolean;
};

const STATUS_COLORS: Record<string, string> = {
  RASCUNHO: 'bg-slate-100 text-slate-700',
  DFD_ELABORACAO: 'bg-blue-100 text-blue-800',
  PESQUISA_PRECO: 'bg-amber-100 text-amber-800',
  ETP_ELABORACAO: 'bg-purple-100 text-purple-800',
  TR_ELABORACAO: 'bg-indigo-100 text-indigo-800',
  EDITAL_ELABORACAO: 'bg-cyan-100 text-cyan-800',
  PARECER_JURIDICO: 'bg-pink-100 text-pink-800',
  PUBLICADO: 'bg-teal-100 text-teal-800',
  EM_ANDAMENTO: 'bg-green-100 text-green-800',
  CONTRATADO: 'bg-emerald-100 text-emerald-800',
  EM_FISCALIZACAO: 'bg-orange-100 text-orange-800',
  CONCLUIDO: 'bg-gray-200 text-gray-900',
  CANCELADO: 'bg-red-100 text-red-700',
};

const STAGES = ['DFD', 'PESQUISA', 'ETP', 'TR', 'EDITAL', 'PARECER', 'CONTRATO'];

export default function HomePage() {
  const [processos, setProcessos] = useState<Processo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiFetch('/processos/')
      .then((data) => {
        setProcessos(data);
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }, []);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-white border-b border-slate-200 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-blue-600 to-blue-800 rounded-lg" />
            <h1 className="text-xl font-bold text-slate-900">LicitaI</h1>
            <span className="text-sm text-slate-500">Piloto · Pregão Eletrônico</span>
          </div>
          <Link
            href="/processos/novo"
            className="bg-blue-700 hover:bg-blue-800 text-white px-4 py-2 rounded-md text-sm font-medium"
          >
            Novo Processo
          </Link>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-6 py-8">
        <h2 className="text-2xl font-bold text-slate-900 mb-6">Processos</h2>

        {loading && <p className="text-slate-500">Carregando…</p>}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-800 rounded-lg p-4 mb-4">
            <strong>Erro:</strong> {error}
            <p className="text-sm mt-2">
              Verifique se a API está rodando e o Supabase configurado.
            </p>
          </div>
        )}

        {!loading && !error && processos.length === 0 && (
          <div className="bg-white border border-slate-200 rounded-lg p-8 text-center">
            <p className="text-slate-600">Nenhum processo cadastrado ainda.</p>
            <Link
              href="/processos/novo"
              className="text-blue-700 hover:underline mt-2 inline-block"
            >
              Criar primeiro processo →
            </Link>
          </div>
        )}

        <div className="space-y-3">
          {processos.map((p) => (
            <Link
              key={p.id}
              href={`/processos/${p.id}`}
              className="block bg-white border border-slate-200 rounded-lg p-4 hover:border-blue-400 hover:shadow-md transition"
            >
              <div className="flex items-start justify-between mb-3">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-1">
                    <span className="text-sm font-mono text-slate-500">
                      {p.numero_ano || '—'}
                    </span>
                    <span
                      className={`text-xs px-2 py-0.5 rounded-full ${
                        STATUS_COLORS[p.status] || 'bg-slate-100'
                      }`}
                    >
                      {p.status}
                    </span>
                  </div>
                  <p className="text-slate-900 font-medium">{p.objeto}</p>
                </div>
                {p.valor_estimado && (
                  <div className="text-right">
                    <p className="text-xs text-slate-500">Valor estimado</p>
                    <p className="text-lg font-semibold text-slate-900">
                      R$ {p.valor_estimado.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </p>
                  </div>
                )}
              </div>

              <div className="flex gap-2">
                {STAGES.map((s) => {
                  const flag = `tem_${s.toLowerCase()}` as keyof Processo;
                  const done = p[flag] as boolean;
                  return (
                    <div
                      key={s}
                      className={`flex-1 text-center text-xs py-1 rounded ${
                        done
                          ? 'bg-green-100 text-green-800 font-medium'
                          : 'bg-slate-100 text-slate-400'
                      }`}
                    >
                      {done ? '✓' : '○'} {s}
                    </div>
                  );
                })}
              </div>
            </Link>
          ))}
        </div>
      </main>
    </div>
  );
}
