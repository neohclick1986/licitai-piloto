'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { apiFetch } from '@/lib/api';

type Processo = {
  id: string;
  numero_ano: string | null;
  objeto: string;
  status: string;
  valor_estimado: number | null;
  area_requisitante: string | null;
  tem_dfd: boolean;
  tem_pesquisa: boolean;
  tem_etp: boolean;
  tem_tr: boolean;
  tem_edital: boolean;
  tem_parecer: boolean;
  tem_contrato: boolean;
};

export default function ProcessoPage() {
  const params = useParams();
  const id = params.id as string;
  const [processo, setProcesso] = useState<Processo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiFetch(`/processos/${id}`)
      .then(setProcesso)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return <div className="p-8">Carregando…</div>;
  if (!processo) return <div className="p-8">Processo não encontrado</div>;

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-white border-b border-slate-200 px-6 py-4">
        <Link href="/" className="text-sm text-slate-600 hover:text-slate-900">
          ← Voltar
        </Link>
      </header>

      <main className="max-w-4xl mx-auto px-6 py-8 space-y-6">
        <div className="bg-white border border-slate-200 rounded-lg p-6">
          <div className="text-sm text-slate-500 font-mono mb-1">
            {processo.numero_ano}
          </div>
          <h1 className="text-2xl font-bold text-slate-900 mb-2">
            {processo.objeto}
          </h1>
          <div className="flex gap-3 text-sm text-slate-600">
            <span>Status: <strong>{processo.status}</strong></span>
            {processo.area_requisitante && (
              <span>Área: {processo.area_requisitante}</span>
            )}
            {processo.valor_estimado && (
              <span>Valor: R$ {processo.valor_estimado.toLocaleString('pt-BR')}</span>
            )}
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          <StageCard
            href={`/processos/${id}/dfd`}
            title="DFD"
            description="Documento de Formalização da Demanda"
            done={processo.tem_dfd}
          />
          <StageCard
            href={`/processos/${id}/pesquisa`}
            title="Pesquisa de Preços"
            description="Mapa com 3+ fontes"
            done={processo.tem_pesquisa}
            disabled={!processo.tem_dfd}
          />
          <StageCard
            href={`/processos/${id}/etp`}
            title="ETP"
            description="Estudo Técnico Preliminar (art. 18)"
            done={processo.tem_etp}
            disabled={!processo.tem_pesquisa}
          />
          <StageCard
            href={`/processos/${id}/tr`}
            title="TR"
            description="Termo de Referência"
            done={processo.tem_tr}
            disabled={!processo.tem_etp}
          />
          <StageCard
            href={`/processos/${id}/edital`}
            title="Edital"
            description="Minuta de Pregão Eletrônico"
            done={processo.tem_edital}
            disabled={!processo.tem_tr}
          />
          <StageCard
            href={`/processos/${id}/juridico`}
            title="Parecer Jurídico"
            description="Análise automatizada"
            done={processo.tem_parecer}
            disabled={!processo.tem_edital}
          />
        </div>
      </main>
    </div>
  );
}

function StageCard({
  href,
  title,
  description,
  done,
  disabled,
}: {
  href: string;
  title: string;
  description: string;
  done: boolean;
  disabled?: boolean;
}) {
  const baseClasses =
    'block rounded-lg border p-4 transition';
  const stateClasses = disabled
    ? 'bg-slate-50 border-slate-200 opacity-50 cursor-not-allowed'
    : done
      ? 'bg-green-50 border-green-200 hover:border-green-400'
      : 'bg-white border-slate-200 hover:border-blue-400 hover:shadow-md';
  if (disabled) {
    return (
      <div className={`${baseClasses} ${stateClasses}`}>
        <CardContent title={title} description={description} done={done} />
      </div>
    );
  }
  return (
    <Link href={href} className={`${baseClasses} ${stateClasses}`}>
      <CardContent title={title} description={description} done={done} />
    </Link>
  );
}

function CardContent({
  title,
  description,
  done,
}: {
  title: string;
  description: string;
  done: boolean;
}) {
  return (
    <>
      <div className="flex items-center justify-between mb-1">
        <h3 className="font-semibold text-slate-900">{title}</h3>
        <span className={done ? 'text-green-600' : 'text-slate-400'}>
          {done ? '✓' : '○'}
        </span>
      </div>
      <p className="text-sm text-slate-600">{description}</p>
    </>
  );
}
