WITH todos_anos AS ( -- Cria CTE com dados de 23 a 25
    SELECT nome_empresa, volume_negociado, tipo_mercado, data_pregao
      FROM b3_cotacoes_2023 
        UNION ALL
    SELECT nome_empresa, volume_negociado, tipo_mercado, data_pregao
      FROM b3_cotacoes_2024 
        UNION ALL
    SELECT nome_empresa, volume_negociado, tipo_mercado, data_pregao
      FROM b3_cotacoes_2025
),

volume_por_empresa AS ( -- Mostra volume total e total de dias negociados de uma empresa
    SELECT
        nome_empresa,
        SUM(volume_negociado) AS volume_total_empresa,
        COUNT(DISTINCT data_pregao) AS dias_negociados
      FROM todos_anos
      WHERE tipo_mercado = 10 -- Filtrando por a vista
     GROUP BY nome_empresa
     ORDER BY volume_total_empresa DESC
),

volume_total_mercado AS ( -- Mostra volume total do mercado
    SELECT SUM(volume_total_empresa) AS volume_total
      FROM volume_por_empresa
),

participacao AS ( -- Mostra participacao percentual das empresas
    SELECT 
        vpe.nome_empresa,
        vpe.volume_total_empresa,
        ((100.0 * vpe.volume_total_empresa) / vtm.volume_total) AS percentual_participacao
      FROM volume_por_empresa vpe CROSS JOIN volume_total_mercado vtm
),
 
ranking AS ( -- Gera classificao de empresas com base em seu percentual de participacao e acumula a participacao
    SELECT 
        ROW_NUMBER() OVER (ORDER BY percentual_participacao DESC) AS ranking, --Cria campo de colocação (1°, 2° ...)
        nome_empresa, 
        volume_total_empresa,
        percentual_participacao,
        SUM(percentual_participacao) OVER (
            ORDER BY percentual_participacao DESC
            ROWS UNBOUNDED PRECEDING -- Soma todas os valores anteriores ao atual da coluna
          ) AS participacao_acumulada
      FROM participacao
),

 concentracao AS ( -- Mostra volume total da empresa, participacao e as enquadra em faixas de percentuais acumulados
    SELECT 
        nome_empresa,
        ROUND(volume_total_empresa / 1000000000000, 2) AS volume_trilhoes_reais,
        ROUND(percentual_participacao, 2) AS percentual_de_participacao, 
        CASE 
          WHEN participacao_acumulada <= 40 THEN 'TOP 40%'
             WHEN participacao_acumulada <= 50 THEN 'TOP 50%'
             WHEN participacao_acumulada <= 60 THEN 'TOP 60%'
             WHEN participacao_acumulada <= 70 THEN 'TOP 70%'
             WHEN participacao_acumulada <= 80 THEN 'TOP 80%'
             ELSE 'DEMAIS'
          END AS grupo_concentracao
      FROM ranking
     ORDER BY percentual_participacao DESC
),

auxiliar_empresas_por_grupo AS ( -- CTE auxiliar: Mostra a quantidade de empresas que estão em uma faixa de participacao sem acumula-las (Empresas TOP 40% nao estao no TOP 50%)
    SELECT 
        grupo_concentracao,
        COUNT(*) AS quantidade_empresas
      FROM concentracao
     GROUP BY grupo_concentracao
     ORDER BY CASE
          WHEN grupo_concentracao = 'TOP 40%' THEN 0
          WHEN grupo_concentracao = 'TOP 50%' THEN 1
          WHEN grupo_concentracao = 'TOP 60%' THEN 2
          WHEN grupo_concentracao = 'TOP 70%' THEN 3
          WHEN grupo_concentracao = 'TOP 80%' THEN 4
          ELSE 5 
         END
),

empresas_por_grupo AS( -- Mostra a quantiade de empresas presentes em uma faixa de participacao (Diferente da auxiliar, empresas TOP 40% entram como TOP 50%)
    SELECT 
        grupo_concentracao,
        SUM(quantidade_empresas) OVER (
            ORDER BY CASE
                  WHEN grupo_concentracao = 'TOP 40%' THEN 0
                  WHEN grupo_concentracao = 'TOP 50%' THEN 1
                  WHEN grupo_concentracao = 'TOP 60%' THEN 2
                  WHEN grupo_concentracao = 'TOP 70%' THEN 3
                  WHEN grupo_concentracao = 'TOP 80%' THEN 4
                  ELSE 5 
                 END
            ROWS UNBOUNDED PRECEDING ) AS quantidade_empresas
      FROM auxiliar_empresas_por_grupo
          ORDER BY CASE
              WHEN grupo_concentracao = 'TOP 40%' THEN 0
              WHEN grupo_concentracao = 'TOP 50%' THEN 1
              WHEN grupo_concentracao = 'TOP 60%' THEN 2
              WHEN grupo_concentracao = 'TOP 70%' THEN 3
              WHEN grupo_concentracao = 'TOP 80%' THEN 4
              ELSE 5 
             END
)

SELECT * FROM empresas_por_grupo
