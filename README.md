# **Gigantes do Mercado: O Poder das Grandes Corporações na B3**

## **Visão Geral do Projeto**

Este projeto apresenta uma análise da estrutura de concentração do mercado de capitais brasileiro, revelando como as principais empresas listadas na B3 lideram setores estratégicos.

### **A Elite Corporativa Brasileira**

A análise identificou uma estrutura de mercado bem estabelecida, com dados iniciando em 2023, abrangendo o período até jun 2025

- **TOP 10% (10 empresas)**: Concentram o núcleo de excelência do mercado
- **TOP 16 empresas**: Representam metade da força econômica total
- **TOP 24 empresas**: Abrangem 60% do poder de mercado
- **37 empresas líderes**: Dominam 70% da participação total

### Ranking do Mercado

| Posição | Empresa | Volume (R$) | Participação | Part. Acumulada |
|---------|---------|-------------|--------------|-----------------|
| 1° | **PETROBRAS** | 118.27 trilhões | 9.63% | 9.63% |
| 2° | **VALE** | 98.08 trilhões | 7.98% | 17.61% |
| 3° | **ITAÚ UNIBANCO** | 50.07 trilhões | 4.08% | 21.69% |
| 4° | **BRADESCO** | 41.85 trilhões | 3.41% | 25.10% |
| 5° | **IBOVESPA** | 35.15 trilhões | 2.86% | 27.96% |
| 6° | **BRASIL** | 32.44 trilhões | 2.64% | 30.60% |
| 7° | **B3** | 32.44 trilhões | 2.57% | 33.18% |


## Metodologia

A análise foi conduzida inteiramente em **SQL**, utilizando uma abordagem estruturada com **CTEs (Common Table Expressions)** para organizar o fluxo dos dados. A base de dados foi composta por registros históricos da B3 entre **2023 e 2025**, contendo informações de pregões diários como nome da empresa, volume negociado, data e tipo de mercado.

### Etapas principais:

1. **Unificação das bases anuais**  
   As tabelas dos anos de 2023, 2024 e 2025 foram unidas com `UNION ALL`, centralizando os dados em uma CTE `todos_anos`.

2. **Filtragem por mercado à vista**  
   Apenas negociações do tipo **mercado à vista** (código 10) foram consideradas, pois representa o núcleo das negociações da B3

3. **Cálculo do volume por empresa**  
   Utilizou-se `SUM(volume_negociado)` para somar o volume negociado por empresa e `COUNT(DISTINCT data_pregao)` para calcular a quantidade de dias negociados.

4. **Participação da empresa no mercado**  
   Com `CROSS JOIN`, cada volume individual foi comparado com o volume total do mercado, obtendo-se a **participação percentual** por empresa.

5. **Ranking e participação acumulada**  
   Foi utilizado `ROW_NUMBER()` para gerar o ranking e `SUM(...) OVER (...)` para calcular a **participação acumulada**, base para definir faixas como “TOP 50%”, “TOP 60%”, etc.

6. **Classificação por grupo de concentração**  
   Cada empresa foi classificada com `CASE WHEN` de acordo com sua contribuição acumulada no mercado.

7. **Análise agregada**  
   Funções como `COUNT(*)`, `SUM(...) OVER` e ordenações personalizadas foram usadas demonstrar a quantidade de empresas por grupo.

*Essa abordagem em SQL permitiu uma análise utilizando recursos nativos da linguagem, sem dependência de ferramentas externas ou pós-processamento.*

## Query completa

```sql
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

SELECT * FROM concentracao;
```

### Resultados

A tabela concentração de participaçao foi gerada utiliando `SELECT * FROM concentracao`

| nome_empresa  | volume_trilhoes_reais | percentual_de_participacao | grupo_concentracao |
|---------------|-----------------------|---------------------------|--------------------|
| PETROBRAS     | 118,27                | 9,63                      | TOP 40%            |
| VALE          | 98,08                 | 7,98                      | TOP 40%            |
| ITAUUNIBANCO  | 50,07                 | 4,08                      | TOP 40%            |
| BRADESCO      | 41,85                 | 3,41                      | TOP 40%            |
| IBOVESPA      | 35,15                 | 2,86                      | TOP 40%            |
| ...           | ...                   | ...                       | ...                |
| AMBEV S/A     | 23,46                 | 1,91                      | TOP 50%            |
| ...           | ...                   | ...                       | ...                |
| HAPVIDA       | 17,33                 | 1,41                      | TOP 60%            |
| ...           | ...                   | ...                       | ...                |
| COPEL         | 12,01                 | 0,98                      | TOP 70%            |



A tabela que representa a quantidade de empresas por grupo de concentração foi gerada utiliando `SELECT * FROM empresas_por_grupo`

| grupo_concentracao | quantidade_empresas |
|--------------------|--------------------|
| TOP 40%            | 10                 |
| TOP 50%            | 16                 |
| TOP 60%            | 24                 |
| TOP 70%            | 37                 |
| TOP 80%            | 56                 |
| DEMAIS             | 846                |


---
## Conclusão 
A concentração de investimentos das empresas negociadas na B3 é um indicativo de estabilidade e influência econômica das mesmas. Gigantes como Petrobras, Vale e os maiores bancos lideram as negociações, impulsionam seus setores, fomentando a inovação e o crescimento econômico. O alto volume indica que há um interesse contínuo pelas empresas, garantindo alta oferta e demanda e consequentemente liquidez.

A liquidez além de ser um atrativo para investidores, por permitir a venda e compra de ativos facilmente, é utilizado como parâmetro para fusões de empresas, pois as grandes empresas podem suas próprias ações como moedas de troca durante a aquisição de outras empresas. 
As ações de grande negociação, disponibilizadas por essas empresas “vitrines” garante à B3 atração de capital internacional, facilitando negociações de grande porte, gerando maior faturamento em taxas com um número pequeno de ativos bem negociados. 


## Como Executar a Análise e fonte de dados

Para reproduzir esta análise, você pode:

- **Baixar os arquivos CSV** utilizados e executar o código SQL localmente, utilizando a ferramenta de sua preferência (DBeaver, DataGrip, etc.);
- **Ou acessar diretamente a consulta pronta** na plataforma Data.World, sem necessidade de configurar nada:

🔗 data.world/wramos/mapa-inteligente-dos-fundos-brasileiros-fiis-e-fidc/workspace/query?queryid=23af6cab-bf8f-449e-8a8a-e199d606be42

Os dados foram retirado 
[Histórico de Market Data da B3](https://www.b3.com.br/pt_br/market-data-e-indices/servicos-de-dados/market-data/historico/)




