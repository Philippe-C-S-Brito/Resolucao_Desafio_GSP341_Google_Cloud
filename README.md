# ☁️ Automação do Desafio GSP341 - Criar modelos de ML com o BigQuery ML

Bem-vindos ao repositório de suporte para o laboratório **GSP341**! 
Este script foi construído para automatizar 100% da criação, treinamento, avaliação e predição dos modelos de Machine Learning utilizando o BigQuery ML, conforme exigido pelo desafio.

## 🚀 Vantagem deste laboratório
Como os nomes dos datasets e modelos neste desafio são padrões, **você não precisa alterar nem preencher nenhuma variável**. É só executar o script!

## ☁️ Como executar no Cloud Shell:

```bash
curl -LO https://raw.githubusercontent.com/Philippe-C-S-Brito/Resolucao_Desafio_GSP341_Google_Cloud/main/bqml_desafio.sh
sudo chmod +x bqml_desafio.sh
./bqml_desafio.sh
```
🎯 Próximos passos:

Copie o bloco de código acima (usando o botão de copiar no canto direito).

Abra o Cloud Shell (o terminal preto) no painel do laboratório do Google Cloud e cole o comando.

Aperte ENTER e assista o script trabalhar!

ATENÇÃO: O treinamento de modelos de Machine Learning exige muito processamento de dados. O script pode parecer "travado" por 2 a 4 minutos durante as Tarefas 1, 3 e 4. Não se preocupe e não cancele a operação, apenas aguarde a mensagem final verde de Sucesso.

Quando o script finalizar, volte ao painel do laboratório e clique nos botões Verificar meu progresso para garantir seus 100%.

Bons estudos!

# Guia Explicativo: Prevendo Compras de Visitantes com BQML (GSP341)

Bem-vindo(a) ao guia de estudos do laboratório **Predict Visitor Purchases with a Classification Model in BQML**. Como especialista em Google Cloud, preparei este material para explicar exatamente o que o script bash fornecido está fazendo nos bastidores. 

O objetivo deste desafio é ensinar como usar o **BigQuery Machine Learning (BQML)** para criar, avaliar e utilizar modelos de *Machine Learning* diretamente usando a linguagem SQL. O cenário é de um e-commerce: queremos prever se um visitante fará uma compra em uma visita futura.

Abaixo está o detalhamento de cada etapa (Tarefa) executada no seu script.

---

## 🛠️ Configuração Inicial e Cores
Logo no início, o script define algumas variáveis de cores (ex: `CYAN_TEXT`, `GREEN_TEXT`). Isso serve apenas para deixar a saída no terminal mais bonita e legível para você, destacando mensagens de sucesso ou avisos.

---

## 🎯 Tarefa 1: Criando o Dataset e o Modelo Inicial

### 1. Criação do Dataset
```bash
bq --location=US mk -d ecommerce 2>/dev/null || true
```
**O que está acontecendo:** Antes de salvar qualquer modelo no BigQuery, precisamos de um "recipiente" chamado *Dataset*. O comando `bq mk` cria um dataset chamado `ecommerce` na região US. 

### 2. Treinando o Modelo Inicial (`customer_classification_model`)
Aqui usamos o comando `bq query` para executar um SQL no BigQuery. O código usa `CREATE OR REPLACE MODEL` para treinar uma inteligência artificial.

* **O Modelo:** É do tipo `logistic_reg` (Regressão Logística). Esse é o algoritmo padrão para classificação binária (respostas de "Sim/Não" ou "1/0").
* **A Label:** A coluna `will_buy_on_return_visit` é o nosso alvo (o que queremos prever). Se for 1, o cliente comprou no retorno. Se for 0, ele não comprou.
* **Os Dados (Features):** Neste modelo mais simples, estamos usando apenas duas características de comportamento do usuário:
    1. `bounces` (taxa de rejeição - o usuário entrou e saiu sem interagir?)
    2. `time_on_site` (tempo gasto no site)
* **O Treinamento:** Utilizamos os dados históricos de **Agosto de 2016 a Abril de 2017** para ensinar o modelo.

---

## 📊 Tarefa 2: Avaliando o Modelo Inicial

Não basta treinar um modelo; precisamos saber se ele é bom!

```sql
SELECT roc_auc, ... FROM ML.EVALUATE(...)
```

**O que está acontecendo:** O comando `ML.EVALUATE` pega o modelo treinado na etapa anterior e testa em **dados novos** (de Maio a Junho de 2017). Se testássemos nos mesmos dados de treinamento, o modelo poderia apenas ter "decorado" as respostas.

* **Métrica `roc_auc`:** A Área Sob a Curva ROC (AUC) mede a qualidade de um modelo de classificação. 
    * 0.5 a 0.6 = Ruim (como jogar uma moeda)
    * 0.7 a 0.8 = Decente
    * 0.8 a 0.9 = Bom
    * > 0.9 = Excelente

O código usa um `CASE WHEN` para classificar o resultado da métrica em texto legível (`'good'`, `'fair'`, etc.). O modelo inicial provavelmente não terá um desempenho espetacular por usar poucas *features*.

---

## 🚀 Tarefa 3: Melhorando o Modelo

Como vimos que o modelo pode melhorar, a Tarefa 3 foca em **Feature Engineering** (Engenharia de Recursos).

### Treinando o `improved_customer_classification_model`
O comando SQL é muito parecido com o da Tarefa 1, mas observe a quantidade de colunas novas adicionadas na cláusula `SELECT`:
* `latest_ecommerce_progress`: Quão longe no funil de vendas o cliente chegou?
* `pageviews`: Quantas páginas ele visualizou?
* `source` e `medium`: De onde o tráfego veio? (orgânico, cpc, etc)
* `deviceCategory`: Qual dispositivo foi usado? (Mobile, Desktop)
* `country`: Qual o país do visitante?

**Por que fazemos isso?** Ao dar mais contexto ao modelo (com mais e melhores dados), o algoritmo de Regressão Logística consegue encontrar padrões mais complexos e, assim, fazer previsões muito mais precisas. Após a criação, o script roda o `ML.EVALUATE` novamente. Você notará que o `roc_auc` aumentará consideravelmente!

---

## 🔮 Tarefa 4: Modelo Finalizado e Predição (O Grande Final!)

### 1. Modelo Finalizado
O script cria uma versão final do modelo (`finalized_classification_model`) usando os mesmos recursos bem-sucedidos da Tarefa 3. 

### 2. Fazendo Previsões (`ML.PREDICT`)
Agora entra a mágica real do Machine Learning: aplicar o modelo para prever o futuro!

```sql
SELECT * FROM ML.PREDICT(MODEL `ecommerce.finalized_classification_model`, (
    ... DADOS DE JULHO E AGOSTO DE 2017 ...
)) ORDER BY predicted_will_buy_on_return_visit DESC
```

**O que está acontecendo:**
A função `ML.PREDICT` recebe o modelo pronto e o aplica a um conjunto de visitantes completamente novos (dados de Julho a Agosto de 2017).
A consulta vai retornar novas colunas, sendo a principal delas a `predicted_will_buy_on_return_visit`. O `ORDER BY DESC` garante que os usuários com as **maiores probabilidades matemáticas de fazerem uma compra** apareçam no topo da lista.

### 💡 Aplicação Prática no Mundo Real:
Com essa lista em mãos, uma equipe de Marketing poderia criar uma campanha de e-mail com cupons de desconto focada **apenas** nos clientes do topo da lista, economizando dinheiro em publicidade e maximizando o retorno (ROI).

---

## 🎉 Conclusão
Ao final do script, você executou o ciclo completo de *Machine Learning* diretamente no seu banco de dados:
1. **Preparação** (Dataset)
2. **Treinamento** (`CREATE MODEL`)
3. **Avaliação** (`ML.EVALUATE`)
4. **Otimização** (Adição de *Features*)
5. **Predição** (`ML.PREDICT`)

Isso mostra o power do BigQuery ML: você não precisou extrair dados, aprender Python, Pandas ou Scikit-Learn. Tudo foi feito com a linguagem SQL nativa da nuvem do Google!
