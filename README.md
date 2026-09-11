# DNKEY

Som de teclado mecânico no macOS — que responde à **força real** da sua batida.

O DNKEY fica discreto no menu bar e toca uma amostra a cada tecla. Nos Macs com Apple Silicon
ele lê o acelerômetro do próprio chassi para medir o impacto de cada batida: digitar leve soa
baixo e agudo, martelar soa alto e mais grave. Em Macs sem esse sensor o app funciona igual,
só com intensidade fixa.

**13 sons inclusos** · Cherry MX Blue, Brown e Black · Holy Panda · Topre · IBM Buckling
Spring · Alpaca Linear · Alps Blue · Kailh BOX Navy · NovelKeys Cream · Gateron Red Ink e
Black Ink · Turquoise Tealios

---

## Instalar

**Requisitos:** macOS 13 Ventura ou qualquer versão mais nova — Ventura, Sonoma, Sequoia,
Tahoe. O app é universal: roda nativo em Apple Silicon (M1 em diante) e em Mac Intel.

### Pelo terminal, sem compilar

Baixa a versão pronta, instala em Aplicativos e já libera a primeira abertura:

```bash
cd "$(mktemp -d)"
curl -L -o DNKEY.zip https://github.com/ANBR007/DNKEY/releases/latest/download/DNKEY.zip
ditto -x -k DNKEY.zip .
rm -rf /Applications/DNKEY.app
mv DNKEY.app /Applications/
xattr -dr com.apple.quarantine /Applications/DNKEY.app
open /Applications/DNKEY.app
```

O `xattr` é o que evita o aviso de "desenvolvedor não identificado" — veja abaixo o que ele
faz e por que é necessário.

### Pelo mouse, sem compilar

1. Baixe o `DNKEY.zip` em **[Releases](https://github.com/ANBR007/DNKEY/releases)**.
2. Descompacte e arraste o **DNKEY.app** para a pasta **Aplicativos**.
3. Clique com o **botão direito** no app e escolha **Abrir**.

### Compilando você mesmo

Precisa do Xcode ou das Command Line Tools (`xcode-select --install`), com Swift 5.9+.

```bash
git clone https://github.com/ANBR007/DNKEY.git
cd DNKEY
./Scripts/install.sh
```

O `install.sh` compila, instala em `/Applications`, substitui a versão anterior se houver e
abre o app. Se quiser só gerar o `.app` sem instalar, rode `./Scripts/build_app.sh` — o
resultado sai em `dist/`.

---

## Primeira abertura — dois avisos do macOS

Esses dois passos são normais e acontecem **uma única vez**.

### 1. "O DNKEY não pôde ser aberto porque é de um desenvolvedor não identificado"

O app não é assinado com uma conta paga da Apple, então o macOS desconfia dele. Para liberar:

- Clique no app com o **botão direito** e escolha **Abrir**, e confirme **Abrir** de novo; ou
- vá em **Ajustes do Sistema › Privacidade e Segurança**, role até o fim e clique em
  **Abrir mesmo assim**.

Se preferir resolver pelo terminal:

```bash
xattr -dr com.apple.quarantine /Applications/DNKEY.app
```

### 2. Permissão de Acessibilidade

É o que permite ao DNKEY saber que uma tecla foi pressionada — sem isso ele abre, mas fica mudo.

Abra o menu do DNKEY no menu bar e clique em **Conceder permissão**, ou vá direto em
**Ajustes do Sistema › Privacidade e Segurança › Acessibilidade** e ligue a chave do **DNKEY**.

O app percebe sozinho quando a permissão chega — **não precisa reabrir**.

Se você concedeu a permissão e mesmo assim ele continua mudo, procure o DNKEY também em
**Privacidade e Segurança › Monitoramento de Entrada** e ligue lá. Algumas versões do macOS
pedem a autorização por esse painel em vez do de Acessibilidade.

> **O DNKEY não registra o que você digita.** Ele escuta em modo somente-leitura: sabe que uma
> tecla desceu e a qual grupo ela pertence (espaço, enter, backspace ou o resto) para escolher
> o som certo. Nada é gravado, nada sai do seu Mac — o app não usa rede.

---

## Usando

O ícone de teclado no menu bar abre todo o painel:

| Controle | O que faz |
|---|---|
| Chave no topo | Liga e desliga o som, sem fechar o app |
| **Som** | Escolhe entre os 13 teclados (e os seus, se importar) |
| **Volume** | Volume do DNKEY, independente do volume do sistema |
| **Responder à força da batida** | Liga a leitura do acelerômetro |
| Bolinha verde | Acelerômetro funcionando. Cinza = seu Mac não tem, e a intensidade fica fixa |
| **Sair** | Fecha o app |

Suas preferências ficam salvas e voltam do jeito que estavam na próxima abertura.

---

## Usando seus próprios sons

Clique em **Importar meus sons** e escolha uma pasta ou arquivos soltos.
Formatos aceitos: **mp3, wav, aiff, m4a, caf, flac**.

Uma pasta com alguns áudios dentro já vira um pack válido. Se quiser o controle completo, um
pack tem esta forma:

```
MeuPack/
  press/     GENERIC_R0.mp3 … GENERIC_R4.mp3    ← até 5 variações, tocadas em rodízio
             SPACE.mp3   ENTER.mp3   BACKSPACE.mp3
  release/   GENERIC.mp3
             SPACE.mp3   ENTER.mp3   BACKSPACE.mp3
```

Nada disso é obrigatório: teclas sem som próprio usam o `GENERIC`, e um pack sem `release/`
simplesmente não faz som quando você solta a tecla.

Os packs importados ficam em `~/Library/Application Support/DNKEY/SoundPacks/` — o botão
**Abrir pasta de sons** leva direto lá.

---

## Desinstalar

Arraste o **DNKEY.app** da pasta Aplicativos para o Lixo. Para apagar também os sons
importados e as preferências:

```bash
rm -rf ~/Library/"Application Support"/DNKEY
defaults delete com.anbr007.dnkey
```

E remova o DNKEY da lista em *Ajustes do Sistema › Privacidade e Segurança › Acessibilidade*.

---

## Licença e créditos

MIT — veja [LICENSE](LICENSE) e [NOTICE.md](NOTICE.md).

Os sons vêm do [ClickClack](https://github.com/cesarferreira/clickclack) (MIT) e a técnica de
leitura do acelerômetro vem de
[apple-silicon-accelerometer](https://github.com/olvvier/apple-silicon-accelerometer) (MIT).
