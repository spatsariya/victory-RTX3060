# Rodar num PC modesto (16 GB de RAM, RTX 3060 12 GB)

O jeito de jogar descrito no [README](../README.md) foi pensado para 64 GB de RAM
e uma placa de 24 GB, com o perfil do Series X. Num PC com 16 GB de RAM, uma
RTX 3060 12 GB e um processador forte (i9 de 14ª geração, por exemplo), três
coisas seguram o frame ao mesmo tempo:

- **a placa**: o jogo desenha em resolução alta, para uma saída 4K;
- **a memória da placa**: 12 GB enchem logo no primeiro frame do mundo, e as
  texturas ficam saindo e voltando;
- **a RAM**: o processo pede de 25 a 46 GB. O que não cabe nos 16 GB vai para
  o arquivo de paginação, e o Windows passa o tempo lendo e gravando no disco.

O perfil `-Leve` piora a imagem para aliviar as três. **Ninguém mediu ele
ainda nessa máquina**: os números do README são de outros PCs. Ele não faz
milagre (a RTX 3060 do README, com 64 GB e o perfil Series X, fez de 1 a 4 fps),
mas ataca exatamente o que trava um PC de 16 GB.

## 1. Uma vez, antes de tudo

1. **Memória virtual (o mais importante com 16 GB).** Win+R, `sysdm.cpl`,
   Avançado, Desempenho: Configurações, Avançado, Memória virtual: Alterar.
   Desmarque "Gerenciar automaticamente", escolha o SSD NVMe mais rápido,
   "Tamanho personalizado": inicial `49152`, máximo `65536` (MB). Definir, OK,
   e reinicie o PC. Sem isso o jogo para com o erro 1455 do Windows ou se
   arrasta.
2. **Compile a build diag** (a única em que `-SkipShaders` funciona):

   ```powershell
   cargo build --locked --profile diag -p victory --features diagnostics
   ```

3. **Traduza os shaders antes** (minutos; pode parar e continuar depois):

   ```powershell
   target\diag\victory.exe shaders <os arquivos de shader do jogo>
   ```

4. **Painel de controle da NVIDIA**, Gerenciar as configurações 3D:
   "Tamanho do cache de shader": `Ilimitado`; "Modo de gerenciamento de
   energia": `Preferir desempenho máximo`.
5. Windows: plano de energia de alto desempenho, e feche navegador, Discord,
   overlays e gravadores antes de jogar (cada GB de RAM conta).

## 2. Jogar

```powershell
.\scripts\play.ps1 -Exe 'C:\caminho\da\sua\copia\do\jogo.exe' -Leve
```

- Fechou sozinho ou travou? Tente de novo com `-Leve -Safe`.
- Ainda pesado? Uma TV de 720p em vez de 1080p: `-Leve -Display 1280x720`.
- O perfil Series S deu problema (tela preta, fecha ao carregar o mundo)?
  Mantenha o resto do perfil com o Series X: `-Leve -Console series-x`.
- A primeira vez com `-Leve` engasga mais: o jogo cria pipelines que as
  corridas com o Series X nunca criaram, e o driver compila cada uma. Depois
  de uma sessão, deixe-as prontas:

  ```powershell
  target\diag\victory.exe warm --used
  ```

## 3. O que o `-Leve` muda

| Ajuste | O que faz |
|---|---|
| `--console series-s` | O jogo escolhe resolução, detalhe e orçamento de memória pelo console em que acha que está. No Series S ele tem 7,6 GB em vez de 13,5 GB: menos RAM, menos memória da placa, menos coisa a desenhar. (No PC do README, preso no processador e com 64 GB, isso não ajudou; aqui a parede é outra.) |
| `VICTORY_DISPLAY_MODE=1920x1080` | O console informa uma TV 1080p em vez de 4K: a saída do jogo, o alvo do upscaler e os passes de tela ficam em 1080p. `-Display` troca o tamanho. |
| `VICTORY_GPU_LOAD_MS=45` | O jogo mede o tempo da placa com timestamps para ajustar a resolução dinâmica. Aqui todos eles são gravados juntos quando o frame termina, então o jogo acha que a placa não fez nada e nunca baixa a resolução. Com 45 ms, acima dos 33 ms que ele quer, ele baixa a resolução interna. |
| `VICTORY_LEVELS_ON_DEMAND=1` | Cópias das texturas na placa só com os níveis que o jogo tem de fato: de 2 a 3 GB livres numa placa de 12 GB. |
| `VICTORY_PIPELINE_WAIT_MS=24` | No máximo 24 ms por frame esperando pipelines que ainda estão sendo feitas (500 ms por padrão): um objeto pode faltar por um ou dois frames, em vez de o frame inteiro parar. |
| `VICTORY_LIST_IDLE=256` | Metade das listas paradas guardadas (512 por padrão). Cada uma segura a memória da maior gravação que já fez, toda em RAM. |

O ray tracing continua desligado (ele custa uns 40 ms por frame na placa), e a
luz ambiente que o substitui (`VICTORY_AMBIENT`) continua ligada: custa quase
nada.

## 4. Tirar shaders

`-SkipShaders` deixa de fora todo desenho e todo dispatch de um programa do
jogo, pelo nome que o compilador do console deu a ele. Um pedaço do nome
basta, e pega todas as variantes de uma vez:

```powershell
.\scripts\play.ps1 -Exe '...' -Leve -SkipShaders 'CS_AccumulateLocalLightInscatteringVolume'
```

(Esse exemplo tira a luz das lâmpadas no ar dos ambientes: a neblina e os
fachos de luz em volta das lâmpadas somem ou ficam mais escuros.)

**Achar os nomes.** A lista de todos os programas, com nome e hash, sai de:

```powershell
target\diag\victory.exe shader-info <os arquivos de shader do jogo> --verbose > D:\fora-do-repositorio\shaders.txt
```

Grave fora da pasta do repositório: o arquivo tem dados do jogo
([docs/asset-policy.md](asset-policy.md)).

**Achar os pesados.** Uma corrida com `-More @{VICTORY_GPU_TIMING='1'}` mede
cada lista da placa sozinha (fica bem mais lenta enquanto mede) e escreve no
log linhas `slow list command, <ms> ms: ...` com os comandos mais lentos e os
hashes dos seus shaders. Um hash entra direto em
`-More @{VICTORY_SKIP_PIPELINES='<16 dígitos>,<16 dígitos>'}`; pelo `shaders.txt`
se acha o nome, que pega as variantes também. O painel do F3 mostra para onde
vai o tempo do frame.

**Cuidado**, um programa a menos não é só um efeito a menos:

- o que vem depois lê o que ele escreveria: tela preta, manchas, sombras que
  somem. Se aparecer, tire o nome da lista;
- **não tire os programas do mar e da água**: o jogo lê no processador as
  texturas de altura do oceano que eles escrevem, e os barcos afundam sem elas;
- prefira pós-processamento e efeitos de ar (neblina, luz volumétrica, desfoque)
  a qualquer coisa de geometria, sombras ou iluminação principal.

## 5. Se ainda estiver lento

- **Gerenciador de Tarefas**, Desempenho: com a memória acima de 90 % e o disco
  sempre ativo, a parede é a RAM. Feche o que puder; a solução de verdade são
  32 GB ou mais.
- O i9 de 14ª geração tem 8 núcleos rápidos (P) e vários de eficiência (E). As
  threads de que o frame depende já ficam nos núcleos P. Dá para testar ainda
  `-More @{VICTORY_LANE_CORE='1'}`: a thread que envia o trabalho à placa fica
  com um núcleo P só para ela (não medido nessa máquina).
- Uma build de release (`cargo build --locked --release -p victory` e
  `-Build release`) não tem os diagnósticos e pode ser um pouco mais rápida,
  mas não tem `-SkipShaders`.
