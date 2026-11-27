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

O `-Leve` vai em níveis (`-Nivel 1` a `4`, 1 se nada for dito). Cada um soma
ao anterior. Os dois primeiros não mudam o jeito como o jogo monta e entrega
a imagem; os dois últimos mudam, e ninguém os testou.

| Nível | Soma | Risco |
|---|---|---|
| 1 (padrão) | A resolução dinâmica do jogo baixa; menos listas paradas em RAM. | Baixo: o jogo desenha do mesmo jeito, só em resolução menor. |
| 2 | Texturas na placa só com os níveis que o jogo usa: 2 a 3 GB livres na placa de 12 GB. | Médio: só foi testado numa placa AMD. |
| 3 | Saída em 1080p em vez de 4K. | Alto: nunca testado. |
| 4 | Perfil do Series S. | Alto: nunca testado no mundo do jogo. |

O primeiro `-Leve` era o nível 4 inteiro, mais uma espera de pipelines de
24 ms, e deixou a tela preta com o som tocando. O mais provável é que tenha
sido a saída 1080p ou o Series S, os dois ajustes que mudam como o jogo
entrega a imagem; por isso estão no fim.

Como testar (um minuto por nível, até o mundo carregar):

1. Rode `-Leve`. Se a imagem aparecer, tente `-Leve -Nivel 2`, depois `3` e `4`.
2. Fique no maior nível que mostra a imagem.
3. Se até o nível 1 ficar preto, rode sem `-Leve`: se a imagem voltar, o
   culpado é o nível 1; se não, o problema é outro.

Cada partida deixa um registro em `%LOCALAPPDATA%\victory\logs` (os 10 mais
novos ficam). Quando o jogo fecha, o script diz se a placa de vídeo caiu, se o
emulador não conseguiu mostrar a imagem, ou se o jogo entregou a imagem em mais
de um plano (o emulador só mostra o primeiro: tela preta com som). Se ficar
preto, mande esse arquivo junto com o nível que usou.

Outros ajustes, à parte dos níveis:

- Fechou sozinho ou travou? Some `-Safe`.
- `-Display 1280x720` ou `-Console series-s` aplicam só aquele ajuste, em
  qualquer nível.
- Engasgos enquanto o driver compila pipelines: depois de uma sessão, deixe-as
  prontas para a próxima:

  ```powershell
  target\diag\victory.exe warm --used
  ```

## 3. O que cada ajuste faz

| Ajuste | Nível | O que faz |
|---|---|---|
| `VICTORY_GPU_LOAD_MS=45` | 1 | O jogo mede o tempo da placa com timestamps para ajustar a resolução dinâmica. Aqui todos eles são gravados juntos quando o frame termina, então o jogo achava que a placa não fazia nada e nunca baixava a resolução. Com 45 ms, acima dos 33 ms que ele quer, ele baixa a resolução interna. |
| `VICTORY_LIST_IDLE=256` | 1 | Metade das listas paradas guardadas (512 por padrão). Cada uma segura a memória da maior gravação que já fez, toda em RAM. |
| `VICTORY_LEVELS_ON_DEMAND=1` | 2 | Cópias das texturas na placa só com os níveis que o jogo tem de fato. |
| `VICTORY_DISPLAY_MODE=1920x1080` | 3 | O console informa uma TV 1080p em vez de 4K: a saída do jogo, o alvo do upscaler e os passes de tela ficam em 1080p. |
| `--console series-s` | 4 | O jogo escolhe resolução, detalhe e orçamento de memória pelo console em que acha que está. No Series S ele tem 7,6 GB em vez de 13,5 GB. |

O ray tracing continua desligado (ele custa uns 40 ms por frame na placa), e a
luz ambiente que o substitui (`VICTORY_AMBIENT`) continua ligada: custa quase
nada. A espera por pipelines voltou aos 500 ms normais; quem quiser trocar
engasgos por objetos que faltam por um ou dois frames pode usar
`-More @{VICTORY_PIPELINE_WAIT_MS='100'}`.

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

## 6. Medir antes de mexer mais

Abaixar a qualidade só ajuda enquanto a placa é a parede. Boa parte do frame é
trabalho do emulador (traduzir as chamadas do jogo, achar e copiar o que o
processador e a placa escreveram), e isso não diminui com a resolução. Para
saber qual parede é a sua:

1. Jogue o mesmo trecho com `-Leve` e com `-Leve -Display 1280x720`. Se o FPS
   quase não mudar, a placa não é a parede.
2. Aperte **F3** no jogo: o painel no canto mostra para onde vai o tempo do
   frame. Tire um print dele parado num lugar.
3. No **Gerenciador de Tarefas**, aba Desempenho, anote a Memória (em uso e
   confirmada), o Disco do arquivo de paginação e, na GPU, "Memória dedicada da
   GPU" e a utilização.
