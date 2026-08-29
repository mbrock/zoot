# A Pretty Expressive Printer

Journal article · Emina Torlak, Justin Pombrio, Sorawee Porncharoenwase · 2023 · Association for Computing Machinery (ACM)

## A Pretty Expressive Printer (with Appendices)

SORAWEE PORNCHAROENWASE, University of Washington, USA

JUSTIN POMBrio, Unaffiliated, USA

EMINA TORLAK, University of Washington, USA

Pretty printers make trade-offs between the *expressiveness* of their pretty printing language, the *optimality* objective that they minimize when choosing between different ways to lay out a document, and the *performance* of their algorithm. This paper presents a new pretty printer, $\Pi_e$, that is strictly more expressive than all pretty printers in the literature and provably minimizes an optimality objective. Furthermore, the time complexity of $\Pi_e$ is better than many existing pretty printers. When choosing among different ways to lay out a document, $\Pi_e$ consults a user-supplied *cost factory*, which determines the optimality objective, giving $\Pi_e$ a unique degree of flexibility. We use the Lean theorem prover to verify the correctness (validity and optimality) of $\Pi_e$, and implement $\Pi_e$ concretely as a pretty printer that we call PRETTYEXPRESSIVE. To evaluate our pretty printer against others, we develop a formal framework for reasoning about the expressiveness of pretty printing languages, and survey pretty printers in the literature, comparing their expressiveness, optimality, worst-case time complexity, and practical running time. Our evaluation shows that PRETTYEXPRESSIVE is efficient and effective at producing optimal layouts. PRETTYEXPRESSIVE has also seen real-world adoption: it serves as a foundation of a code formatter for Racket.

CCS Concepts: • **Software and its engineering** → **Functional languages**; • **Mathematics of computing** → **Combinatorial optimization**.

Additional Key Words and Phrases: pretty printing

### ACM Reference Format:

Sorawee Porncharoenwase, Justin Pombrio, and Emina Torlak. 2023. A Pretty Expressive Printer (with Appendices). *Proc. ACM Program. Lang.* 7, OOPSLA2, Article 261 (October 2023), 34 pages. [https://doi.org/10.1145/3622837](https://doi.org/10.1145/3622837)

### 1 INTRODUCTION

General-purpose pretty printers (or, simply, *printers*) are widely used to convert structured data—typically an AST—into human-readable text. Their applications include code reformatting, software reengineering, and synthesized code printing [De Jonge 2002; Prettier 2016; Torlak and Bodik 2014; Yelland 2015]. These printers take as inputs (1) a document in a pretty printing language (PPL), which encodes the structured data along with formatting choices, and (2) a page width limit. Choices in the document can yield exponentially many possible layouts. The task of the printers is then to efficiently choose an optimal layout from all possible layouts. Existing printers use a variety of built-in optimality objectives. A good objective reflects the informal notion of “prettiness,” such as not overflowing past the page width limit whenever possible, while having as few lines as possible.

Authors’ addresses: Sorawee Porncharoenwase, Paul G. Allen School of Computer Science & Engineering, University of Washington, Seattle, WA, USA, sorawee@cs.washington.edu; Justin Pombrio, Unaffiliated, Cambridge, MA, USA, jpombrio@cs.brown.edu; Emina Torlak, Paul G. Allen School of Computer Science & Engineering, University of Washington, Seattle, WA, USA, emina@cs.washington.edu.

Permission to make digital or hard copies of part or all of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for third-party components of this work must be honored. For all other uses, contact the owner/author(s).

© 2023 Copyright held by the owner/author(s).

2475-1421/2023/10-ART261

[https://doi.org/10.1145/3622837](https://doi.org/10.1145/3622837)

Different printers make different trade-offs in the *expressiveness* of the PPL, the *optimality* objective, and the *performance*. This paper presents a printer that we call $\Pi_e$. It targets $\Sigma_e$, a PPL that is strictly more expressive than all published PPLs. This can be shown via our formal framework for reasoning about the expressiveness of PPLs. $\Pi_e$ is parameterized by a *cost factory*, which enables users to specify an optimality objective for $\Pi_e$ to minimize. The cost factory is versatile. For example, it can express non-linear costs and define concepts such as soft page width limits [Yelland 2016]. As a result, the optimal layout that $\Pi_e$ chooses can have higher quality compared to existing printers. The time complexity of $\Pi_e$ is $O(nW^4)$, where $n$ is the size of the document and $W$ is the computation width limit (defined in Section 6). This is better than the time complexity of many printers in the literature, and it is improved to $O(nW^3)$ when $\Pi_e$ is restricted to process documents in some well-known but less expressive PPLs. We prove the correctness of $\Pi_e$ in the Lean theorem prover [Moura and Ullrich 2021], ensuring the validity and optimality of the output layout, and demonstrate $\Pi_e$'s efficiency by evaluating our implementation of $\Pi_e$, which we call PRETTYEXPRESSIVE. We believe these attributes make $\Pi_e$ not only a good printer by itself, but also a good building block to construct other derived printers.

*A Survey of Printers in the Wild.* To evaluate $\Pi_e$, we conducted a broad survey of the literature on pretty printing. Most PPLs, embedded in a host programming language, provide a small set of core constructs that allow users to create a document with text, concatenate documents together, set indentation level, and express formatting choices. High-level constructs can then be built on top of the core constructs. The details of these core constructs can differ from PPL to PPL. We found that there are two main schools of PPLs in the wild, which we call the *traditional* and *arbitrary-choice* PPLs. The traditional PPL centers around manipulation of `nls` (newlines) and current indentation level, while the arbitrary-choice PPL is characterized by the ability to express arbitrary formatting choices and the use of aligned concatenation to supplant the concept of indentation level. Figure 1 illustrate documents in both PPLs that pretty-print the function definition `append` in a hypothetical programming language with slightly different styling.

*Expressiveness.* The literature contains informal claims about the expressiveness of PPLs [Chitil 2005; Podkopaev and Boulytchev 2015; Wadler 2003]. We develop two formal notions of expressiveness: the ability to *express layouts* and the ability to *express features*. The former reflects the functionality of a PPL, while the latter reflects the ease of document construction. Using our framework, we can show that neither the traditional PPL nor the arbitrary-choice PPL is more expressive than the other. For example, the set of layouts in Figure 1b cannot be expressed by any document in the traditional PPL. This is because all layouts due to a particular document in the traditional PPL must be the same modulo whitespace, but one of the layouts in the figure has an extra pair of parentheses.[^1] As another example, the document in Figure 1b is awkwardly constructed, because the document structure and the underlying AST structure do not match (Section 5.3). It would be more natural to use unaligned concatenation, but the feature cannot be expressed by any combination of features in the arbitrary-choice PPL.[^2] To that end, we develop a PPL called $\Sigma_e$ that is strictly more expressive than both the traditional and arbitrary-choice PPLs, facilitating both functionality and ease of document construction.

[^1]: Languages such as Python require an extra pair of parentheses around an expression that spans multiple lines [The Python Language Reference 2010]. Similarly, some styles prefer adding an extra comma (also known as trailing comma) when a function call spans multiple lines [ESLint 2014]. Hence, the ability to express layouts with differing content is desirable.

[^2]: Different programming language styles prefer different concatenation operators. C-like languages heavily use unaligned concatenation, while aligned concatenation has been used for Haskell, Lisp, R, and Julia. However, there are instances where C-like languages would benefit from aligned concatenation, and Haskell would benefit from unaligned concatenation.

text "function_append(first,second,third){" 1 function append(first,second,third){
<> nest 4 ( 2 return first +
let f = text "first_+" in 3 second +
let s = text "second_+" in 4 third
let t = text "third" in 5 }
nl <> text "return_" <>
group (nest 4 (f <> nl <> s <> nl <> t)) 1 function append(first,second,third){
) <> nl <> text "}" } 2 return first + second + third
3 }

(a) A document in the traditional PPL and its corresponding layouts. The `nest` construct increments the current indentation level by some specified amount, causing `nl` (newline) to insert indentation spaces. `<>` is the unaligned concatenation operator, which places the right sub-layout after the left sub-layout on the current indentation level. Lastly, the `group` construct creates a choice between two alternatives: one where the sub-layouts are left alone and one where the sub-layouts are flattened by replacing newlines and indentation spaces due to `nls` in the group with single spaces.

text "function_append(first,second,third){" <> 1 function append(first,second,third){
( let f = text "first_+" in 2 return (
let s = text "second_+" in 3 first +
let t = text "third" in 4 second +
let sp = text " " in 5 third
let ret = text "return_" in 6 )
text "..." <> 7 }
(((ret <> text "(") <>
(text "..." <> (f <> s <> t)) <>
text ")") <>
(ret <> f <> sp <> s <> sp <> t))
<> text "}" } 1 function append(first,second,third){
2 return first + second + third
3 }

(b) A document in the arbitrary-choice PPL and its corresponding layouts. `<|>` is the arbitrary-choice operator, which per its namesake, creates a choice between the layouts of two arbitrary sub-documents. `<>` is the vertical concatenation operator, which joins two sub-layouts with a newline. Lastly, `<>>` is the aligned concatenation operator, which joins two sub-layouts horizontally, aligning the whole right sub-layout at the column where it is to be placed in.

Fig. 1. The traditional and arbitrary-choice PPLs, embedded in the host language OCaml. Colored regions in a document and corresponding layouts indicate the correspondence between the colored sub-documents and the colored sub-layouts. We use the `let` construct to make the documents easier to read, even though it is usually not a part of PPLs. Dotted lines illustrate different page width limits at 22 and 36 characters.

*Optimality.* The optimality objective of a printer indicates what it optimizes for when resolving choices. Most printers targeting the traditional PPL minimize overflow past the page width limit line-by-line, preferring a longer line when there is no overflow. For example, given the document in Figure 1a, the first layout is optimal when the page width limit is 22 (red dotted line), while the second layout is optimal when the page width limit is 36 (green dotted line). Contrary to prior claims [Chitil 2005; Wadler 2003], we discovered that this strategy guarantees neither the absence of overflow whenever possible nor the minimality of the number of lines. By contrast, most printers targeting the arbitrary-choice PPL minimize the number of lines among layouts with no overflow. However, they *error* when all possible layouts have an overflow, resulting in a poor user experience (e.g., when the page width limit is 22 in Figure 1b). Recognizing that unavoidable overflows do occur in practice, we introduce the concept of a *cost factory*, which allows users to choose a desired objective permitted by its interface, including an objective that tolerates overflow gracefully.

*Performance.* Printing proceeds in two phases: resolving choices and rendering the optimal choice to text (although many printers fuse these two phases together). Time complexity of printers is best measured against the resolving phase[^3], and it is usually specified with two parameters: the size of the document $n$ and the width limit $W$, with the preference that the time complexity be polynomial in $W$ and linear in $n$. Most printers in the literature leave their time complexity unanalyzed, instead opting to show experimental results that their implementations are efficient in practice. We analyze these printers and demonstrate documents that trigger worse than linear time behavior (in $n$) on some printers. Further complication arises in printers with the arbitrary choice feature, which gives rise to documents that are structured as DAGs as opposed to trees. We show that many printers that treat the input document as a tree suffer from a combinatorial explosion as the DAG structure is unfolded during the resolving phase, resulting in exponential time complexity. With a combination of proof and experimental results, we show that the time complexity of $\Pi_e$ is linear in the DAG size of the document and that it runs fast in practice.

In summary, this paper makes the following contributions:

- A new PPL called $\Sigma_e$ that is strictly more expressive than all published PPLs. The constructs in $\Sigma_e$ are not new, but packaging them all in a single PPL has never been done before.
- A printer $\Pi_e$ targeting $\Sigma_e$ that utilizes a *cost factory* to allow a variety of optimality objectives.
- A proof of correctness (validity and optimality) for $\Pi_e$, formalized in the Lean theorem prover. To our knowledge, this is the first time that a printer has been formally verified.
- A framework to formally reason about the expressiveness of PPLs.
- A survey of printers and an analysis that dispels common misunderstandings about them.
- An implementation of $\Pi_e$, PRETTYEXPRESSIVE, and an evaluation that shows its effectiveness.

The rest of this paper is structured as follows. **Section 2** surveys the related work. **Section 3** provides an overview of $\Pi_e$ from the user’s perspective. **Section 4** presents the formal semantics of $\Sigma_e$. **Section 5** introduces a framework to reason about the expressiveness of PPLs. **Section 6** formally presents $\Pi_e$ and its analysis. **Section 7** discusses PRETTYEXPRESSIVE, an implementation of $\Pi_e$. **Section 8** presents an evaluation of PRETTYEXPRESSIVE that demonstrates its effectiveness. Lastly, **Section 9** concludes the paper.

### 2 RELATED WORK

To understand the trade-off space of printer designs, we conduct a comprehensive analysis of related work in the literature. This section provides our analysis of the printers, grouped by the expressiveness of their public interface[^4]. The summary is presented in **Table 1**. We then compare and contrast our printer $\Pi_e$ against them.

#### 2.1 Traditional Printers

Pretty printing has a long history. Oppen [1980] first introduced a general-purpose printer, written in the imperative style. Oppen pioneered the PPL that we call the traditional PPL, shown in **Figure 2a**. Instead of representing an input document as a tree, as commonly done in subsequent work, Oppen represents the document as a stream of “instruction tokens.” The algorithm’s time complexity is $O(n)$, where $n$ is the length of the stream. Furthermore, the algorithm is *bounded*, requiring a limited look-ahead into the stream. As with other printers in this family, the printer greedily

[^3]: This formulation allows us to talk about “linear-time” printers, even though there are, e.g., documents whose size is $O(n)$, but its optimal layout has $O(n^2)$ characters.

[^4]: In practice, printers include extensions that increase their expressiveness. A printer may even have different expressiveness across different versions. This section focuses on the core features of these printers as specified in their publications.

Table 1. A comparison of existing printers. $n$ and $\hat{n}$ are the DAG size and tree size of the input document (where $\hat{n}$ in the worst case is exponential in $n$). $W$ is the width limit.

| Printer | Expressiveness<br>Choice | Expressiveness<br>Concatenation | Optimality<br>Minimization objective | Performance<br>Time complexity |
| --- | --- | --- | --- | --- |
| Oppen [1980] | Group | Unaligned | Lexicographic overflow | $O(n)$ |
| Hughes [1995] | Group | Aligned | Lexicographic overflow | $O(n^2)$ |
| Wadler [2003] | Group | Unaligned | Lexicographic overflow | $O(n^2)$ |
| Leijen [2000] | Group | Both | Lexicographic overflow | $O(n^2)$ |
| Chitil [2005] | Group | Unaligned | Lexicographic overflow | $O(n)$ |
| Kiselyov et al. [2012] | Group | Unaligned | Lexicographic overflow | $O(n)$ |
| Swierstra et al. [1999] | Arbitrary | Aligned | Height † | Exp. in $n$ |
| Podkopaev and Boulytchev [2015] | Arbitrary | Aligned | Height † | $O(\hat{n}W^4)$ |
| Yelland [2016] | Arbitrary | Aligned | Linear cost | $O(\hat{n}^{3/2})$ |
| Bernardy [2017c] | Arbitrary | Aligned | Height † | $O(nW^6)$ |
| $\Pi_e$ | Both | Both | Cost (from the cost factory) | $O(nW^4)$ |
| $\Pi_e$ (aligned only) | Both | Aligned | Cost (from the cost factory) | $O(nW^3)$ |

† only consider layouts without an overflow past $W$.

|  |  |  |  |
| --- | --- | --- | --- |
| $d \in \mathcal{D} ::= \text{text } s$ | text | $d \in \mathcal{D} ::= \text{text } s$ | text |
| $\mid \text{n1}$ | newline | $\mid d_a \langle \rightarrow \rangle d_b$ | aligned concatenation |
| $\mid d \langle \rightarrow \rangle d$ | unaligned concatenation | $\mid d_a \langle \rightarrow \rangle d_b$ | vertical concatenation |
| $\mid \text{nest } n d$ | increase the indentation level by $n$ | $\mid d_a \langle \rightarrow \rangle d_b$ | an arbitrary choice |
| $\mid \text{group } d$ | a choice between<br>flattening or not flattening |  |  |

Fig. 2. A comparison between the traditional and arbitrary-choice PPLs. $s$ denotes a string without newline, and $n$ denotes a natural number.

minimizes overflow past the page width limit, which neither avoids overflow whenever possible nor minimizes number of lines, as discussed in Oppen’s paper.

Wadler [2003] designed a printer that targets the traditional PPL. It is used in many real world applications, such as an industrial code formatter [Prettier 2016], and as a basis for much pretty printing research [Chitil 2005; Kiselyov et al. 2012]. The printer aims to be a rewrite of Oppen’s printer using the functional style employed by Hughes (described later). The printer is claimed [Chitil 2005; Wadler 2003] to produce an output layout that does not exceed the width limit whenever possible, and minimizes the number of lines. However, this is not the case, as shown in Figure 16 in Appendix A. The time complexity of the printer is claimed to be $O(n)$ where $n$ is the size of document [Wadler 2003], but it is in fact $O(n^2)$ in the worst case, as demonstrated in Figure 17, although this worst case behavior is unlikely to occur in practice.

Chitil [2005] improved Wadler’s printer so that it is as efficient as Oppen’s, $O(n)$, by using lazy dequeues. Kiselyov et al. [2012] similarly improved Wadler’s printer via their generator framework.

Compared to traditional printers, $\Pi_e$ is more expressive as it allows arbitrary choices and aligned concatenation. Furthermore, $\Pi_e$ can produce an output layout that minimizes number of lines when the output layout does not exceed the page width limit, and does not exceed the page width limit whenever possible. The tradeoff is that $\Pi_e$ is less space efficient and slower than traditional printers. The space complexity of traditional printers is sub-linear in the size of document, which was especially important decades ago when memory is scarce. The space complexity of $\Pi_e$ is $O(nW^3)$ let shared := D in (shared <> text "!" ) <|> ((shared <> nl) <> text "!")

(a) A document that encodes (at least) two possible layouts. $D$ is an arbitrary sub-document.

*[Figure: Figure 3a: A tree representation of a document. The root node is '<|>'. It has two children: '<>' and '<>'. The left '<>' has a child 'D' (triangle) and a child 'text]*

(b) A tree representation of Figure 3a. $D$ contributes to the size twice.

*[Figure: Figure 3c: A DAG representation of the same document. The root node is '<|>'. It has two children: '<>' and '<>'. The left '<>' has a child 'D' (triangle) and a child 'text]*

(c) A DAG representation of Figure 3a. $D$ contributes to the size only once.

Fig. 3. An example document that shows the importance of treating document as a DAG rather than a tree. The red and pink paths illustrate that the DAG is *properly shared*, as will be discussed in Section 6.4.

in the worst case (or $O(nW^2)$ when targeting some PPLs). We find that, on modern machines, the added memory consumption and performance overhead are rarely an issue in practice (Section 8).

#### 2.2 Arbitrary-Choice Printers

Azero Alcocer and Swierstra [1998] introduced a printer that supports aligned concatenation and choices between arbitrary alternatives. It started the line of work that targets the arbitrary-choice PPL, shown in Figure 2b. The printer’s optimality objective is to avoid overflow whenever possible and produce a minimal number of lines. However, it does not have the ability to cope with unavoidable overflow. This printer was soon superseded by Swierstra et al. [1999], which improves its performance via heuristics and adds the capability to *share* a sub-document across choices by deeply embedding the (equivalent of a) **let** construct in the PPL. As a result, the later printer can process documents that are structured as DAGs rather than trees, as shown in Figure 3. Nonetheless, the time complexity of both printers is exponential in $n$ [Podkopaev and Boulytchev 2015].

Podkopaev and Boulytchev [2015] improved upon Swierstra et al.’s work by formulating the problem as dynamic programming. This fixes the exponential blowup in the prior work, but treats the document as a tree, making its time complexity $O(\hat{n}W^4)$, where $\hat{n}$ is the tree size of the document, which could be exponentially larger than its DAG size. The paper acknowledges the problem and surmises that memoization may be able to address it.

The paper by Bernardy [2017c] is the main inspiration for our work. The printer uses Pareto frontiers to find an optimal layout. By shallowly embedding the PPL (in Haskell), computations on sub-documents are effectively shared for free. However, as presented in the paper, the printer requires the page width limit to be hard-coded. In the actual implementation [Bernardy 2017b], the page width limit is customizable, accomplished by threading the value through functions. But this change destroys the shared computations, leading to exponential running time. Compared to Podkopaev and Boulytchev [2015]’s work, Bernardy [2017c]’s approach can exploit sparseness to improve practical efficiency, but the use of an inefficient algorithm makes the time complexity of the printer $O(nW^6)$ in the worst case. While the paper does not handle unavoidable overflow, the implementation does by automatically scaling up the page width limit (or equivalently, minimizing the maximum overflow). This, however, allows avoidable overflow elsewhere, as shown in Figure 18 in Appendix A, which is undesirable. Later on, Bernardy abandoned the arbitrary-choice operator, noting that it could trigger the exponential behavior [Bernardy 2017a].

Yelland [2016] similarly targeted the arbitrary-choice PPL. However, the paper took a very different approach. The core printer restricts the use of aligned concatenation by requiring the left sub-document to be a **text** syntactically. This restriction allows the core printer to utilize the concept of “piecewise linear cost function” to seemingly boost its performance. To achieve the expressiveness of the arbitrary-choice PPL, the printer employs rewriting rules to transform the original document into the restricted document. While the work carefully avoids exponential blowup by sharing sub-documents in the resulting restricted document, it does not necessarily preserve the sharing structure of the original document, as demonstrated in Figure 19 in Appendix A. Compound this with the lack of a computation width limit, and the number of piecewise linear cost functions under consideration could be as large as $O(\hat{n}^{1/2})$, making the time complexity $O(\hat{n}^{3/2})$ in total, as shown in Figure 20. Another aspect to consider is the printer’s optimality objective, which is restricted to minimizing a linear combination of quantities like the number of lines and overflow. Hence, the work will not technically avoid overflow whenever possible (although the overflow coefficient can be made arbitrarily large to arbitrarily discourage overflow). On the other hand, this optimality objective can support unique features, such as incorporating the costs due to multiple soft page width limits.

Compared to arbitrary-choice printers, $\Pi_e$ is more expressive as it allows unaligned concatenation. $\Pi_e$ is also asymptotically faster than most arbitrary-choice printers, as it treats a document as a DAG rather than a tree. Like Yelland’s printer, for each layout under consideration, $\Pi_e$ keeps track of two quantities: cost and last line length. This is different from most printers in the family which keep track of three quantities: height, width, and last width. The dimension reduction further makes $\Pi_e$ more efficient. The concept of cost also allows $\Pi_e$ to decouple the page width limit and computation width limit, which allows graceful overflow handling. $\Pi_e$, unlike Yelland’s printer, is parameterized by a cost factory, which supports a variety of optimality objectives without requiring a modification to the core printer. This includes not only the linear optimality objectives that Yelland’s printer supports, but also non-linear optimality objectives that can properly avoid overflows.

#### 2.3 Other Printers

Coutaz [1984] introduced one of the earliest document abstractions for user interfaces. The abstraction is very general: it can not only describe text layout, but also image and objects on computer screen. Due to its minimality, it is much less expressive than other printers for textual printing.

Hughes [1995] brought pretty printing to the functional world. The work pioneers using combinators to construct a document for pretty printing, which is now a standard practice. The printer targets a PPL that is neither the traditional nor arbitrary-choice PPL, but somewhere in-between. In particular, it only supports aligned concatenation and does not provide the arbitrary-choice operator in the public interface. The work is more similar to the traditional printers in how it makes choices greedily, which minimizes neither overflow nor number of lines. The combination of greedy choice making and aligned concatenation makes some documents print very poorly [Bernardy 2017c]. Furthermore, Peyton-Jones [1997] identified quadratic time complexity in the printer.

Leijen [2000] implemented Wadler’s printer in Haskell and added support for aligned concatenation via the inclusion of **align**, becoming the first printer that supports both aligned and unaligned concatenation. However, similar to Hughes’ printer, the printer can produce very poor output [Bernardy 2017c].

### 3 AN OVERVIEW OF \Pi_e

$\Pi_e$ takes as inputs a document in $\Sigma_e$, a cost factory, and a computation width limit, and returns a textual layout. This section provides an overview of $\Pi_e$ from the user’s perspective—what form the inputs take, and how they interact to produce a layout.

Document $d \in \mathcal{D}_e := \text{text } s \mid \text{nl} \mid d \diamond d \mid \text{nest } n \ d \mid \text{align } d \mid \text{flatten } d \mid d \langle \rangle \mid d$      String without newline $s, t, \dots \in \text{Str}$

|  |  |
| --- | --- |
| Cost type $\tau$ |  |
| $\leq_{\mathcal{F}} : \tau \rightarrow \tau \rightarrow \mathbb{B}$ | $\leq_{\mathcal{F}}$ must be a total ordering (transitive, antisymmetric, and total) |
| $+_{\mathcal{F}} : \tau \rightarrow \tau \rightarrow \tau$ | $\forall C_1, C_2, C_3, C_4 \in \tau. [C_1 \leq_{\mathcal{F}} C_2 \rightarrow C_3 \leq_{\mathcal{F}} C_4 \rightarrow C_1 +_{\mathcal{F}} C_3 \leq_{\mathcal{F}} C_2 +_{\mathcal{F}} C_4]$ |
| $\text{text}_{\mathcal{F}} : \mathbb{N} \rightarrow \mathbb{N} \rightarrow \tau$ | $\forall c, c', l \in \mathbb{N}. [c \leq c' \rightarrow \text{text}_{\mathcal{F}}(c, l) \leq_{\mathcal{F}} \text{text}_{\mathcal{F}}(c', l)]$ |
| $\text{nl}_{\mathcal{F}} : \tau$ | $\forall c, l_1, l_2 \in \mathbb{N}. \text{text}_{\mathcal{F}}(c, l_1 + l_2) = \text{text}_{\mathcal{F}}(c, l_1) +_{\mathcal{F}} \text{text}_{\mathcal{F}}(c + l_1, l_2)$ |
|  | $+_{\mathcal{F}}$ must be associative, with the identity that is $\text{text}_{\mathcal{F}}(0, 0)$ |
|  | $\forall c \in \mathbb{N}. \text{text}_{\mathcal{F}}(c, 0) = \text{text}_{\mathcal{F}}(0, 0)$ |

Fig. 6. The cost factory interface. Users need to supply the cost type $\tau$ and implement the operations satisfying the contracts indicated in the interface.

1 ← 3 →= f unc ( pretty, print )
2 pretty,
3 print
4 ) !

Fig. 7. Two example layouts to illustrate how a cost factory computes their costs. Both layouts are rendered at column position 3. The dotted lines shows the width limit of 6 and 14.

The nesting doesn't visibly increase the indentation level by 42. To see why, note that `nest 42 ...` is rendered at the column position 1 and indentation level 0. Subsequently, `align ...` is rendered at the column position 1 and indentation level 42. Then, `text "b" <> nl <> text "c"` is rendered at the column position 1 and indentation level 1. That is, the alignment on the inner document overrides the indentation level. This example shows the importance of the indentation level, and why it must be specifically tracked.

This concludes our internal description of how a choiceless document renders to a layout. General documents, by contrast, can contain the (arbitrary-) choice operator `<|>`, which provides a choice among the layouts from two sub-documents. Thus, unlike choiceless documents, which render to a single layout, general documents will *evaluate* to a non-empty, finite set of layouts. Intuitively, this is done by first *widening* a document into a set of choiceless documents, then rendering each choiceless document in the set, producing a set of layouts.

*Example 3.3.* The document `(text "a" <|> text "b") <> (text "c" <|> text "d")` widens to four choiceless documents: `text "a" <> text "c"`, `text "a" <> text "d"`, `text "b" <> text "c"`, and `text "b" <> text "d"`. Thus, the document evaluates (with column position and indentation level 0) to a set of four layouts: "ac", "ad", "bc", and "bd".

#### 3.2 Cost Factory

To pick an optimal layout from the set of layouts that a document evaluates to, $\Pi_e$ needs to be able to compute a cost for each layout, and to compare these costs to find a layout with minimal cost. To accommodate a wide range of optimality objectives, we allow the user to specify a cost type $\tau$ and implement operations on the cost type:

- a procedure $\text{text}_{\mathcal{F}}(c, l)$ that computes the cost of text starting at column $c$ of length $l$
- a constant $\text{nl}_{\mathcal{F}}$ that gives the cost of a newline[^5]
- a procedure $+_{\mathcal{F}}$ that adds two costs together
- a procedure $\leq_{\mathcal{F}}$ that compares two costs

We call this set of parameters a *cost factory*. These parameters cannot be arbitrary, however. For example, the cost of "hello_world" placed at column 10 should be the same as the cost of "hello_"

[^5]: In our Lean formalization and actual implementation, $\text{nl}_{\mathcal{F}}$ is a procedure. See Section 7 for details.

placed at column 10 combined with the cost of “world” placed at column 16.[^6] Thus, a *valid* cost factory also needs to additionally satisfy the contracts listed in Figure 6.[^7] The first three contracts allow $\Pi_e$ to efficiently prune away suboptimal costs during incremental cost computation (Section 6), and the last three contracts ensure that the concept of the cost for a layout is well-defined.

With a cost factory, we can inductively compute the cost of a layout with lines $l_1, l_2, \dots, l_n$ rendered at column position $c$:

$$
\begin{aligned} \text{COST}([l_1], c) &= \text{text}_{\mathcal{F}}(c, |l_1|) \\ \text{COST}([l_1, l_2, \dots, l_{n-1}, l_n], c) &= \text{COST}([l_1, l_2, \dots, l_{n-1}], c) +_{\mathcal{F}} \text{nl}_{\mathcal{F}} +_{\mathcal{F}} \text{text}_{\mathcal{F}}(0, |l_n|) \end{aligned}
$$

$\Pi_e$ can then use $\leq_{\mathcal{F}}$ to find an optimal layout. The following example shows a concrete cost factory and how it can be used to pick an optimal layout among the layouts in Figure 7.

*Example 3.4.* Consider an optimality objective that minimizes the sum of *overflows* (the number of characters that exceed a given *page width limit* $w$ in each line), and *then* minimizes the *height* (the total number of newline characters, or equivalently, the number of lines minus one). This objective is thus able to avoid the excessive overflow problem in Bernardy’s printer described in Section 2.

More concretely, the cost of a layout is a pair of the overflow sum and the height, where lexicographic order determines which cost is less. With $w = 6$, the first layout in Figure 7 has the cost $(20, 0)$, whereas the second layout has the cost $(4 + 3 + 1 + 0, 3) = (8, 3)$. Thus, the second layout is the optimal layout that $\Pi_e$ should pick.

We implement this optimality objective with the following cost factory $\mathcal{F}$.

$$
\begin{aligned} \tau = \mathbb{N} \times \mathbb{N} \quad \leq_{\mathcal{F}} &= \leq_{\text{lex}} \quad (o_a, h_a) +_{\mathcal{F}} (o_b, h_b) = (o_a + o_b, h_a + h_b) \\ \text{text}_{\mathcal{F}}(c, l) &= (\max(c + l - \max(w, c), 0), 0) \quad \text{nl}_{\mathcal{F}} = (0, 1) \end{aligned}
$$

According to $\mathcal{F}$, the first layout has cost $\text{text}_{\mathcal{F}}(3, 26) = (20, 0)$, while the second layout has the cost $\text{text}_{\mathcal{F}}(3, 7) +_{\mathcal{F}} \text{nl}_{\mathcal{F}} +_{\mathcal{F}} \text{text}_{\mathcal{F}}(0, 9) +_{\mathcal{F}} \text{nl}_{\mathcal{F}} +_{\mathcal{F}} \text{text}_{\mathcal{F}}(0, 7) +_{\mathcal{F}} \text{nl}_{\mathcal{F}} +_{\mathcal{F}} \text{text}_{\mathcal{F}}(0, 1) = (8, 3)$, as expected.

The cost factory interface is versatile. The above example shows that $\Pi_e$ does not need to take a page width limit as an input, because the concept of page width limit can already be defined by users via $\text{text}_{\mathcal{F}}$. It is also possible, for example, to implement *soft* width limits, or to compute a linear combination of height and overflow in the style of Yelland [2016]. The rest of this section provides a couple more examples of other valid and invalid cost factories.

*Example 3.5.* The following cost factory targets an optimality objective that minimizes the sum of *squared* overflows over the page width limit $w$, and then the height. This optimality objective is an improvement over the one in Example 3.4 by discouraging overly large overflows. With $w = 6$, the first layout in Figure 7 has the cost $(20^2, 0)$ whereas the second layout has the cost $(4^2 + 3^2 + 1^2 + 0^2, 3)$ The text cost formula is derived from the identity $(a + b)^2 - a^2 = b(2a + b)$ where in each text placement, $a$ is the starting position count past $w$ and $b$ is the overflow length. This is (essentially) the default cost factory that our implementation, PRETTYEXPRESSIVE, employs.

$$
\begin{aligned} \tau = \mathbb{N} \times \mathbb{N} \quad \leq_{\mathcal{F}} &= \leq_{\text{lex}} \quad (o_a, h_a) +_{\mathcal{F}} (o_b, h_b) = (o_a + o_b, h_a + h_b) \quad \text{nl}_{\mathcal{F}} = (0, 1) \\ \text{text}_{\mathcal{F}}(c, l) &= \begin{cases} (b(2a + b), 0) & \text{if } c + l > w \\ (0, 0) & \text{otherwise} \end{cases} \quad \text{where} \quad \begin{aligned} a &= \max(w, c) - w \\ b &= c + l - \max(w, c) \end{aligned} \end{aligned}
$$

[^6]: In other words, the cost of a long text should be able to be broken down into the costs of its characters.

[^7]: For mathematical readers, a (valid) cost factory forms a totally ordered monoid with translational invariance.

*Example 3.6.* The following cost factory targets an optimality objective that minimizes the maximum overflow over the page width limit $w$. With $w = 6$, the first layout in Figure 7 has the cost 20 whereas the second layout has the cost $\max(4, 3, 1, 0) = 4$.

$$
\begin{aligned} \tau = \mathbb{N} \quad \leq_{\mathcal{F}} = \leq \quad m_a +_{\mathcal{F}} m_b = \max(m_a, m_b) \quad \text{nl}_{\mathcal{F}} = 0 \\ \text{text}_{\mathcal{F}}(c, l) = \begin{cases} 0 & \text{if } l = 0 \\ \max(0, c + l - w) & \text{otherwise} \end{cases} \end{aligned}
$$

The above cost factories are all valid. This is proven with automated theorem proving via Rosette 4 [Porncharoenwase et al. 2022; Torlak and Bodik 2014] and Z3 [De Moura and Bjørner 2008].

**THEOREM 3.7.** *The cost factories in Example 3.4, Example 3.5, and Example 3.6 are valid.*

*Example 3.8.* The following *invalid* cost factory intends to target an optimality objective that minimizes the maximum overflow over the page width limit $w$, and then the height. However, the second contract is violated, because $(0, 1) +_{\mathcal{F}} (2, 0) \leq_{\mathcal{F}} (1, 0) +_{\mathcal{F}} (2, 0)$ does not hold.

$$
\begin{aligned} \tau = \mathbb{N} \times \mathbb{N} \quad \leq_{\mathcal{F}} = \leq_{\text{lex}} \quad (m_a, h_a) +_{\mathcal{F}} (m_b, h_b) = (\max(m_a, m_b), h_a + h_b) \quad \text{nl}_{\mathcal{F}} = (0, 1) \\ \text{text}_{\mathcal{F}}(c, l) = \begin{cases} (0, 0) & \text{if } l = 0 \\ (\max(0, c + l - w), 0) & \text{otherwise} \end{cases} \end{aligned}
$$

#### 3.3 \mathcal{W}, the Computation Width Limit

The last input to $\Pi_e$ is $\mathcal{W}$, the computation width limit. When printing a document $d$, $\Pi_e$ only provides the optimality guarantee among layouts evaluated from $d$ whose column position or indentation level during the printing process does not exceed $\mathcal{W}$. For each choiceless document widened from $d$, when its rendering causes a column position or indentation level to exceed the computation width limit, the rendering is *tainted*. For example, if a document evaluates to two layouts in Figure 7, with $\mathcal{W} = 14$, the rendering to the first layout would be tainted, while the rendering to the second layout would not (assuming the indentation level during the rendering doesn't exceed the limit). Layouts from tainted rendering can usually be discarded right away, except when every possible rendering is tainted. In such case, $\Pi_e$ keeps one layout so that it can still output a layout, but provides no guarantee that the layout will be optimal. The tainting system allows us to bound the computation so that the algorithm is efficient.

### 4 THE SEMANTICS OF \Sigma_e

This section formally presents $\Sigma_e$, an expressive PPL. We begin this section by describing *layouts*, which are the textual outputs. Then, we formally describe the semantics of $\Sigma_e$, which is determined by the evaluation of a document in $\Sigma_e$ to a set of layouts.

#### 4.1 Layouts

A *layout* $l \in \mathcal{L}$ is a textual output. We represent a layout as a non-empty, finite list of lines (implicitly joined by newlines), where each line is a string without the newline character.[^8] This allows us to easily reason about the number of lines and the length of each line. The first line of a layout can be put at an arbitrary column position (depending on which column position it is rendered at), but subsequent lines must be put at the column position 0.

*Example 4.1.* The second layout in Figure 7 is `["func(", "_pretty,", "_print", ")"]`, which is rendered at the column position 3.

[^8]: The representation in our Lean formalization is more elaborated, making indentation level explicit by incorporating the information into a layout. We present a simplified version here for the sake of simplicity. See Section 7 for details.

$$
\begin{array}{c}
\text{TEXT} \frac{}{\langle \mathbf{text} \ s, c, i, f \rangle \Downarrow_{\mathcal{R}} [s]} \quad \text{FLATTEN} \frac{\langle \vec{d}, c, i, \top \rangle \Downarrow_{\mathcal{R}} [s]}{\langle \mathbf{flatten} \ \vec{d}, c, i, f \rangle \Downarrow_{\mathcal{R}} [s]} \\
\text{LINENOFLATTEN} \frac{}{\langle \mathbf{nl}, c, i, \perp \rangle \Downarrow_{\mathcal{R}} [\epsilon, \text{"\_"} \times i]} \quad \text{LINEFLATTEN} \frac{}{\langle \mathbf{nl}, c, i, \top \rangle \Downarrow_{\mathcal{R}} [\text{"\_"}]} \\
\text{CONCATONE} \frac{\langle \vec{d}_a, c, i, f \rangle \Downarrow_{\mathcal{R}} [s] \quad \langle \vec{d}_b, c + |s|, i, f \rangle \Downarrow_{\mathcal{R}} [t, t_1, \dots, t_n]}{\langle \vec{d}_a \diamond \vec{d}_b, c, i, f \rangle \Downarrow_{\mathcal{R}} [s \mathbin{++} t, t_1, \dots, t_n]} \quad \text{CONCATMULT} \frac{\langle \vec{d}_a, c, i, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n, s] \quad \langle \vec{d}_b, |s|, i, f \rangle \Downarrow_{\mathcal{R}} [t, t_1, \dots, t_m]}{\langle \vec{d}_a \diamond \vec{d}_b, c, i, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n, s \mathbin{++} t, t_1, \dots, t_m]} \\
\text{NEST} \frac{\langle \vec{d}, c, i + n, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n]}{\langle \mathbf{nest} \ n \vec{d}, c, i, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n]} \quad \text{ALIGN} \frac{\langle \vec{d}, c, c, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n]}{\langle \mathbf{align} \ \vec{d}, c, i, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n]}
\end{array}
$$

$$
\begin{array}{c}
\text{TEXTWIDEN} \frac{}{\mathbf{text} \ s \Downarrow_{\mathcal{W}} [\mathbf{text} \ s]} \quad \text{LINEWIDEN} \frac{}{\mathbf{nl} \Downarrow_{\mathcal{W}} [\mathbf{nl}]} \\
\text{CONCATWIDEN} \frac{d_a \Downarrow_{\mathcal{W}} \vec{D}_a \quad d_b \Downarrow_{\mathcal{W}} \vec{D}_b}{d_a \diamond d_b \Downarrow_{\mathcal{W}} \{ \vec{d}_a \diamond \vec{d}_b \mid \vec{d}_a \in \vec{D}_a, \vec{d}_b \in \vec{D}_b \}} \\
\text{NESTWIDEN} \frac{d \Downarrow_{\mathcal{W}} \vec{D}}{\mathbf{nest} \ n \ d \Downarrow_{\mathcal{W}} \{ \mathbf{nest} \ n \vec{d} \mid \vec{d} \in \vec{D} \}} \quad \text{ALIGNWIDEN} \frac{d \Downarrow_{\mathcal{W}} \vec{D}}{\mathbf{align} \ d \Downarrow_{\mathcal{W}} \{ \mathbf{align} \ \vec{d} \mid \vec{d} \in \vec{D} \}} \\
\text{FLATTENWIDEN} \frac{d \Downarrow_{\mathcal{W}} \vec{D}}{\mathbf{flatten} \ d \Downarrow_{\mathcal{W}} \{ \mathbf{flatten} \ \vec{d} \mid \vec{d} \in \vec{D} \}} \quad \text{UNIONWIDEN} \frac{d_a \Downarrow_{\mathcal{W}} \vec{D}_\alpha \quad d_b \Downarrow_{\mathcal{W}} \vec{D}_\beta}{d_a \triangleleft \triangleright d_b \Downarrow_{\mathcal{W}} \vec{D}_\alpha \cup \vec{D}_\beta}
\end{array}
$$

Fig. 8. Semantics for $\Sigma_e$. “$\epsilon$” is the empty string. “$s \times i$” is the notation for replicating the string $s$ for $i$ times. “$s \mathbin{++} t$” is a string concatenation of $s$ and $t$. Lastly, “$s_1, \dots, s_n$” and “$s_1, \dots, s_n$” indicate $n$ lines, where $n \geq 0$ and $n \geq 1$ respectively.

#### 4.2 The Formal Semantics of \Sigma_e

Our approach to evaluate a document in $\Sigma_e$ to a set of layouts is to first *widen* a document into a set of choiceless documents, then render each choiceless document in the set, producing a set of layouts.

The formal semantics of $\Sigma_e$ consists of two relations, shown in Figure 8. The judgment $\langle \vec{d}, c, i, f \rangle \Downarrow_{\mathcal{R}} l$ states that the choiceless document $\vec{d} \in \vec{D}_e$ placed at column position $c \in \mathbb{N}$ with indentation level $i \in \mathbb{N}$ and flattening mode $f \in \mathbb{B}$, will render to the layout $l \in \mathcal{L}$. Unlike the informal semantics in Section 3.1, we make the flattening mode $f$, which indicates whether newlines should be replaced with spaces, explicit. Its value can be either on ($\top$) or off ($\perp$). Another judgment $d \Downarrow_{\mathcal{W}} \vec{D}$ states that a document $d \in \mathcal{D}_e$ is widened to a finite, non-empty set of choiceless documents $\vec{D} \in 2^{\vec{D}_e}$. We sometimes call a combination of $c$ and $i$ (and possibly $f$) a *printing context*. Now, we elaborate some interesting rules in the figure.

*Rendering Text.* The TEXT rule states that the rendering of a text placement **text** $s$ contains a layout with a single line of the text $s$. The printing context is completely ignored.

*Rendering Newlines.* When the flattening mode is off, the LINENOFLATTEN rule states that the rendering of a **nl** results in a layout with two lines. The first line is empty, while the second line is indented by $i$ spaces. On the other hand, when the flattening mode is on, the LINEFLATTEN rule states that the rendering of the newline results in a layout with a single line of a single space.

*Rendering Unaligned Concatenation.* In the rendering of $\bar{d}_a \diamond \bar{d}_b$, we recursively render $\bar{d}_a$ and $\bar{d}_b$, but the rendering of $\bar{d}_b$ is dependent on the rendering of $\bar{d}_a$. Let $l_a$ be the rendering result of $\bar{d}_a$. The **CONCATONE** rule handles the case where $l_a$ has a single line, and the **CONCATMULT** rule handles the case where $l_a$ has multiple lines.

- If $l_a$ has only a single line $s$, the column position of $\bar{d}_b$'s rendering needs to be after the string $s$ is placed, i.e. at $c + |s|$. In such case, let $l_b$ be the rendering result of $\bar{d}_b$. The first line of the resulting layout is the concatenation of $s$ and the first line of $l_b$. The rest of the lines are from the rest of $l_b$.
- On the other hand, if $l_a$ has multiple lines, the column position of $\bar{d}_b$'s rendering is simply the column position after the last line is placed. In such case, let $l_b$ be the rendering result of $\bar{d}_b$, the resulting layout contains all but the last line of $l_a$, a concatenation of the last line of $l_a$ and the first line of $l_b$, and the rest of $l_b$.

*Widening Choices.* The **UNIONWIDEN** rule states that the widening of $d_a \langle | \rangle d_b$ is the union of widen $d_a$ and widen $d_b$.

Both $\Downarrow_{\mathcal{R}}$ and $\Downarrow_{\mathcal{W}}$ are deterministic and total. Thus, we can define $\text{eval}_e(d) = \{l : \langle \bar{d}, 0, 0, \perp \rangle \Downarrow_{\mathcal{R}} l, \bar{d} \in \bar{D}, d \Downarrow_{\mathcal{W}} \bar{D}\}$ as the evaluation function for $\Sigma_e$, which consumes a document, widens it, and produces a set of layouts.

### 5 A FRAMEWORK TO REASON ABOUT EXPRESSIVENESS

In previous sections, we informally made claims about expressiveness of PPLs. This section presents a framework to formally reason about it, based on two notions: *functional completeness* and *definability*. We first define the semantics of the traditional and arbitrary-choice PPLs. Then, we define our framework, and show that $\Sigma_e$ is strictly more expressive than both the traditional and arbitrary-choice PPLs while being minimal.

In particular, [Theorem 5.12](#) states that every construct in the traditional and arbitrary-choice PPLs is definable in $\Sigma_e$. However, [Theorem 5.17](#) states that some of these constructs are not definable in the traditional and arbitrary-choice PPLs. Finally, [Theorem 5.19](#) shows that $\Sigma_e$ is minimal. Proof sketches of theorems in this section are provided in [Appendix B](#).

#### 5.1 The Extended Semantics

To reason about the traditional and arbitrary-choice PPLs, we need to precisely define their semantics. To do so, we construct a PPL $\Sigma_{\text{all}}$ that contains all constructs from $\Sigma_e$ and the traditional and arbitrary-choice PPLs by extending [Figure 8](#) with [Figure 9](#) (along with the straightforward widening rules). Note that we follow [Wadler [2003]](#)'s approach by treating **group** $d$ as a syntactic sugar for $d \langle | \rangle \text{flatten } d$. As $\langle | \rangle$ and **flatten** are already in $\Sigma_{\text{all}}$, we do not need to adjust anything further.

The extended semantics are still deterministic and total. The semantics of the traditional and arbitrary-choice PPLs is then the restricted semantics of $\Sigma_{\text{all}}$ that only allows their constructs.[^9] Throughout this section, we assume that any PPL is similarly a sublanguage of $\Sigma_{\text{all}}$, whose semantics is well-defined and consistent with $\Sigma_{\text{all}}$.

[^9]: It is worth noting that there are many ways to specify rules to be consistent with the intended semantics of the arbitrary-choice PPL. For instance, an invariant in the the arbitrary-choice PPL is that $c = i$ throughout the rendering process. As a result, we could substitute the **VERTCONCATNOFLATTEN** rule with its variant that changes the premise $\langle \bar{d}_b, i, i, \perp \rangle \Downarrow_{\mathcal{R}} [t_1, \dots, t_m]$ to $\langle \bar{d}_b, c, c, \perp \rangle \Downarrow_{\mathcal{R}} [t_1, \dots, t_m]$, without affecting the semantics of the arbitrary-choice PPL. However, this change could affect the semantics of $\Sigma_{\text{all}}$ and subsequent theorems in this section. We pick **VERTCONCATNOFLATTEN** over the variant because it seemingly integrates better with other constructs in $\Sigma_{\text{all}}$.

$$
\begin{array}{l}
\text{VERTCONCATNOFLATTEN} \frac{\langle \bar{d}_a, c, i, \perp \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n] \quad \langle \bar{d}_b, i, i, \perp \rangle \Downarrow_{\mathcal{R}} [t_1, \dots, t_m]}{\langle \bar{d}_a \<\!\!\> \bar{d}_b, c, i, \perp \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n, t_1, \dots, t_m]} \\
\\
\text{VERTCONCATFLATTEN} \frac{\langle \bar{d}_a, c, i, \top \rangle \Downarrow_{\mathcal{R}} [s] \quad \langle \bar{d}_b, c+1+|s|, i, \top \rangle \Downarrow_{\mathcal{R}} [t]}{\langle \bar{d}_a \<\!\!\> \bar{d}_b, c, i, \top \rangle \Downarrow_{\mathcal{R}} [s \# \text{"\_"} \# t]} \\
\\
\text{ALIGNEDCONCATONE} \frac{\langle \bar{d}_a, c, i, f \rangle \Downarrow_{\mathcal{R}} [s] \quad \langle \bar{d}_b, c+|s|, c+|s|, f \rangle \Downarrow_{\mathcal{R}} [t, t_1, \dots, t_n]}{\langle \bar{d}_a \<\!\!\> \bar{d}_b, c, i, f \rangle \Downarrow_{\mathcal{R}} [s \# t, t_1, \dots, t_n]} \\
\\
\text{ALIGNEDCONCATMULT} \frac{\langle \bar{d}_a, c, i, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n, s] \quad \langle \bar{d}_b, |s|, |s|, f \rangle \Downarrow_{\mathcal{R}} [t, t_1, \dots, t_m]}{\langle \bar{d}_a \<\!\!\> \bar{d}_b, c, i, f \rangle \Downarrow_{\mathcal{R}} [s_1, \dots, s_n, s \# t, t_1, \dots, t_m]}
\end{array}
$$

Fig. 9. The semantics extension.

#### 5.2 Functional Completeness

In Section 1, we claimed that the traditional PPL cannot express the two layouts in Figure 1b, as one layout has an extra pair of parentheses. The question that we may want to ask in general then is, given a PPL $\Sigma$ and a non-empty set of layouts $L$, is it possible to construct a document in $\Sigma$ that evaluates to $L$? This motivates us to define the notion of functional completeness for PPLs.

*Definition 5.1.* A PPL $\Sigma$ with an evaluation function $\text{eval}(\cdot)$ is *functionally complete* if for any non-empty set of layouts $L$, there exists a document $d$ in $\Sigma$ such that $\text{eval}(d) = L$.

With this definition, we can formally reason about some PPLs that we have previously seen.

LEMMA 5.2. *The arbitrary-choice PPL and $\Sigma_e$ are functionally complete.*

LEMMA 5.3. *The traditional PPL is not functionally complete.*

LEMMA 5.4. *For each construct $\mathbf{F}$ in $\{\text{text}, \<\!\!\>, \text{n1}, \<|\!>\}$, $\Sigma_e$ without $\mathbf{F}$ is not functionally complete.*

If we limit the notion of expressiveness to only functional completeness, then all functionally complete PPLs would be equally expressive. However, intuitively this is clearly not the case. The proof of Lemma 5.2 in Appendix B shows that it suffices for a PPL to only have **text**, **<>**, and **<|>** for functional completeness, yet such a PPL would not be pleasant to use compared to $\Sigma_e$, because of the lack of features to, e.g., adjust indentation level. In a sense, functional completeness for PPLs is similar to Turing completeness for programming languages, which similarly does not fully capture expressiveness for programming languages. The next subsection presents a more fine-grained notion of expressiveness, based on the ability to define features.

#### 5.3 Definability

The proof of Lemma 5.2 shows that while $\Sigma_e$ doesn't have **<>**, we can simply expand $d_a \<\!\!\> d_b$ to $d_a \<\!\!\> \text{n1} \> d_b$, which are in $\Sigma_e$, to perform the same functionality. In other words, the construct **<>** is already *definable* by **<>** and **n1**. Thus, adding **<>** to $\Sigma_e$ doesn't increase its expressiveness. By contrast, **<>** is not definable by any combination of features in the arbitrary-choice PPL. To achieve the functionality of **<>**, it would require a non-local restructuring of the document, making it difficult to construct the document in natural way. In this sense, the inability to define a construct in a PPL means that adding the construct to the PPL increases its expressiveness.

More concretely, consider the document in the arbitrary-choice PPL shown in Figure 1b. The document is awkwardly constructed. The **return** keyword must be distributed to combine with a first line of the returned expression, due to the undefinability of unaligned concatenation. This creates a disconnection between the document structure and the underlying AST structure, making it more tedious and error-prone to construct documents. By contrast, the following document is a rewrite of [Figure 1b](#) to utilize the full expressiveness of $\Sigma_e$ in a natural way. The sub-document colored blue fully corresponds to the “returned expression,” allowing users to recursively construct documents naturally.

text "function_append(first,second,third){" <> nest 4 (
let f = text "first_+" in let s = text "second_+" in let t = text "third" in
nl <> text "return_" <>
((text "(" <> (nest 4 (nl <> (f <> nl <> s <> nl <> t))) <> nl <> text ")") <|>
let sp = text "_" in (f <> sp <> s <> sp <> t))
) <> nl <> text "}"

The notion of definability (also known as expressibility) for programming languages was first developed by [Felleisen [1991]](#), and we adapt it for PPLs through a series of definitions as follows:

*Definition 5.5.* A PPL $\Sigma$ consists of:

- a set of (possibly infinitely many) function symbols $\Sigma = \{F, \dots\}$. The function symbols are referred to as *constructs*. Each may have different arity, argument sorts, and resulting sort.
- a non-empty set of documents $\mathcal{D}$ generated from $\Sigma$, where a document is a term of sort Doc.
- an evaluation function $\text{eval} : \mathcal{D} \rightarrow 2^{\mathcal{L}}$.

*Example 5.6.* $\Sigma_e$ contains **nest**, which is a construct with arity 2 of resulting sort Doc. The first argument to **nest** has sort $\mathbb{N}$ and the second argument has sort Doc. $\Sigma_e$ also contains all natural numbers and strings with no newline, which are constructs with arity 0 of resulting sort $\mathbb{N}$ and Str respectively. The evaluation function for $\Sigma_e$ is $\text{eval}_e$ from [Section 4.2](#).

Henceforth, unless indicated otherwise, $\mathcal{D}_X$ and $\text{eval}_X$ are the set of documents and the evaluation function for the PPL $\Sigma_X$.

*Definition 5.7.* A *syntactic abstraction* $\mathbf{M}(\alpha_1, \dots, \alpha_n)$ of arity $n$ for a PPL $\Sigma$ is a document in $\Sigma \cup \{\alpha_1, \dots, \alpha_n\}$ where $\alpha_1, \dots, \alpha_n$ are metavariables of some sorts. An *instance* $\mathbf{M}(e_1, \dots, e_n)$ is a document in $\Sigma$ that substitutes $\alpha_i$ with $e_i$ in $\mathbf{M}(\alpha_1, \dots, \alpha_n)$ for all $1 \leq i \leq n$, where $e_i$ and $\alpha_i$ must have a compatible sort.

*Example 5.8.* $\mathbf{M}(\alpha_1, \alpha_2) = \alpha_1 \diamond \text{nl} \diamond \alpha_2$ is a syntactic abstraction for $\Sigma_e$, where $\alpha_1$ and $\alpha_2$ have sort Doc. On the other hand, $\mathbf{M}'(\alpha_1) = \text{nest } \alpha_1 \text{ nl} \diamond \alpha_1$ is **not** a syntactic abstraction because the first occurrence of $\alpha_1$ requires it to have sort $\mathbb{N}$, but the second occurrence requires it to have sort Doc. An instance $\mathbf{M}(\text{text "a", text "b"})$ is the document $\text{text "a"} \diamond \text{nl} \diamond \text{text "b"}$, but $\mathbf{M}(\text{text "a", 1})$ is not an instance due to the incompatible sort.

*Definition 5.9.* Let $\Sigma_{\text{base}}$ be a PPL and $\Sigma_{\text{extended}} = \Sigma_{\text{base}} \cup \{\mathbf{F}\}$ where $\mathbf{F}$ has arity $n$ with resulting sort Doc. A *syntactic expansion* $\text{expand}_{\mathbf{M}}^{\mathbf{F}}(d)$ from $\Sigma_{\text{extended}}$ to $\Sigma_{\text{base}}$ is a function from $\mathcal{D}_{\text{extended}}$ to $\mathcal{D}_{\text{base}}$ that replaces every occurrence of $\mathbf{F}(e_1, \dots, e_n)$ with an instance $\mathbf{M}(e_1, \dots, e_n)$ in $d$, where $\mathbf{F}$ and $\mathbf{M}$ must have compatible arity and sort arguments.

*Example 5.10.* $\text{expand}_{\mathbf{M}}^{\mathbf{F}}(\cdot)$ is a syntactic expansion from $\Sigma_e \cup \{\mathbf{F}\}$ to $\Sigma_e$, where $\mathbf{M}$ is from [Example 5.8](#). Hence, $\text{expand}_{\mathbf{M}}^{\mathbf{F}}(\text{text "a"} \mathbf{F} \text{ text "b"}) = \text{text "a"} \diamond \text{nl} \diamond \text{text "b"}$.

We are now ready to define definability.[^10]

[^10]: One important distinction of this definition and Felleisen’s counterpart is that PPLs are *total*. Hence, observing termination behavior, as done in Felleisen’s work, is not feasible in our formulation.

*Definition 5.11.* Let $\Sigma_{\text{base}}$ be a PPL and $\Sigma_{\text{extended}} = \Sigma_{\text{base}} \cup \{\mathbf{F}\}$. We say that $\mathbf{F}$ is *definable* by $\Sigma_{\text{base}}$ if there exists a syntactic abstraction $\mathbf{M}$ from $\Sigma_{\text{extended}}$ to $\Sigma_{\text{base}}$ such that for every document $d \in \mathcal{D}_{\text{extended}}$, $\text{eval}_{\text{extended}}(d) = \text{eval}_{\text{base}}(\text{expand}_{\mathbf{F}}^{\mathbf{M}}(d))$.

We can now present one of our main results:

**THEOREM 5.12.** *Every construct in the traditional and arbitrary-choice PPLs is definable in $\Sigma_e$.*

Despite the result, one might wonder if $\Sigma_e$ is actually needed. Could it be that the arbitrary-choice PPL can already define every construct in the traditional PPL? As we foreshadowed, the answer to this question is negative. However, we must first develop tools that allow us to answer the question, again following the development in Felleisen’s work.

*Definition 5.13.* A context $C(\alpha)$ for $\Sigma$ is a unary syntactic abstraction for $\Sigma$ where $\alpha$ has sort Doc.

*Definition 5.14.* Given a PPL $\Sigma$ and a relation $R \subseteq 2^{\mathcal{L}} \times 2^{\mathcal{L}}$, the relation $E_R^{\Sigma}(d_1, d_2)$ holds if and only if $R(\text{eval}(C(d_1)), \text{eval}(C(d_2)))$ holds for all contexts $C$ in $\Sigma$.[^11]

*Example 5.15.* Let $\text{maxWidth} : \mathcal{L} \rightarrow \mathbb{N}$ be a function that computes the maximum length across all lines in the input layout, and lift $\text{maxWidth}$ to work on any set of layouts. That is, $\text{maxWidth}(L) = \{\text{maxWidth}(l) : l \in L\}$. Furthermore, let $R = \{(L_1, L_2) : \text{maxWidth}(L_1) = \text{maxWidth}(L_2)\}$.

- $E_R^{\Sigma_e}(\text{text "a"}, \text{text "b"})$ holds by induction. Intuitively, this is because (1) if we only observe the width, the textual content doesn’t matter, and (2) there is no construct in $\Sigma_e$ that allows us to lay out differently in a way that would affect the width based on the textual content.
- On the other hand, $\neg E_R^{\Sigma_e}(\text{text "a"}, \text{text "aa"})$. For example, with $C(\alpha) = \alpha$, we have that $\text{maxWidth}(\text{eval}_e(C(\text{text "a"}))) = \{1\}$, but $\text{maxWidth}(\text{eval}_e(C(\text{text "aa"}))) = \{2\}$.

The following theorem provides a tool to prove that a construct is not definable in a PPL.

**THEOREM 5.16.** *Given a PPL $\Sigma$ and a construct $\mathbf{F}$, if there exists two documents $d_1$ and $d_2$ in $\Sigma$ and a relation $R$ such that $E_R^{\Sigma}(d_1, d_2)$, but $\neg E_R^{\Sigma \cup \{\mathbf{F}\}}(d_1, d_2)$, then $\mathbf{F}$ is not definable in $\Sigma$.*

With this tool, we are able to prove that some constructs of $\Sigma_{\text{all}}$ are not definable in the traditional and arbitrary-choice PPLs:

**THEOREM 5.17.** *The following is true:*

- $\langle \rangle$ is not definable in the arbitrary-choice PPL.
- **nest** is not definable in the arbitrary-choice PPL.
- **group** is not definable in the arbitrary-choice PPL.
- $\langle \rangle \rangle$ is not definable in the traditional PPL.

Next, we show a relationship between functional completeness and definability.

**LEMMA 5.18.** *If $\Sigma$ is not functionally complete, but $\Sigma \cup \{\mathbf{C}\}$ is, then $\mathbf{C}$ is not definable in $\Sigma$.*

Lastly, we present our final result for this section: $\Sigma_e$ is *minimal* in the sense that each of its constructs is not definable by $\Sigma_e$ without it.

**THEOREM 5.19.** *For any construct $\mathbf{F}$ of $\Sigma_e$, $\mathbf{F}$ is not definable in $\Sigma_e \setminus \{\mathbf{F}\}$.*

[^11]: The relation $E_R^{\Sigma}$ is a generalization of the operational equivalence relation in Felleisen’s work.

*[Figure: Architecture diagram of our pretty printer, Π_e. The diagram shows a process flow: an input document (blue icon) and a cost factory (blue icon) feed into a 'resolve' step, which produces a 'resolved measure set' (orange cloud icon containing document icons). This set is then used to 'pick optimal' an 'optimal measure / optimal choiceless document' (green document icon). Finally, this document is 'rendered' (dotted arrow) to produce a 'printed, optimal layout' (green document icon). A computation width limit (blue icon) is also shown as an input to the resolve step. The entire process is labeled Π_e.]*

Fig. 10. Architecture diagram of our pretty printer, $\Pi_e$

*[Figure: Relationship between evaluation and printing diagram. On the left, a legend defines icons: input document (blue), measure / choiceless document (black), optimal measure / optimal choiceless document (green), resolved measure set (orange cloud), evaluated layout (black document), and printed, optimal layout (green document). It also defines arrows: 'widens to' (solid black) and 'renders to' (dotted black). On the right, a graph shows 'cost' on the y-axis and 'last' on the x-axis. A tree of document icons represents possible layouts. A path is highlighted from the input document through several intermediate layouts to the 'printed, optimal layout' (green).]*

Fig. 11. Relationship between evaluation and printing

### 6 OUR PRINTER, \Pi_e

In this section, we describe our printer, $\Pi_e$, which targets the PPL $\Sigma_e$ presented in Section 4. $\Pi_e$ is parameterized by a cost factory and a computation width limit $\mathcal{W}$. We start with an overview of $\Pi_e$. Then, we define a *measure*, which is an output from the core printer that allows us to record a cost and at the same time avoid a full-blown, expensive rendering. After that, we describe the requirements of the input document structure, which will become important when we analyze the time complexity of the printer. Then, we present $\Pi_e$'s printing algorithm, which utilizes the cost factory to achieve optimal and efficient printing. Finally, we analyze the time complexity of $\Pi_e$.

#### 6.1 Overview

So far we have defined the *evaluation* of a document, which produces the set of possible layouts. But when we *print* a document, we wish to output only a single, optimal layout.

A naïve approach would be to evaluate the input document, via widening and rendering, to all possible layouts, determine costs of these layouts according to a given optimality objective, and then pick one with the least cost as the optimal layout. However, this approach is not practical for two reasons. First, widening could produce exponentially many choiceless documents. Second, rendering non-optimal choiceless documents is unnecessary and wasteful.

A better approach would utilize early pruning to reduce the search space, and avoid rendering until an optimal choiceless document is first identified. The need to prune early motivated the design of the cost factory interface shown in Figure 6, which allows $\Pi_e$ to incrementally compute

$$
\begin{aligned}
\text{Measure } m \in \mathcal{M} &= \langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}} \\
\text{last} : \mathcal{M} &\rightarrow \mathbb{N} \quad \text{last}(\langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = l \quad \text{cost} : \mathcal{M} \rightarrow \tau \quad \text{cost}(\langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = c \\
\text{doc} : \mathcal{M} &\rightarrow \overline{\mathcal{D}_e} \quad \text{doc}(\langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = \bar{d} \\
\text{maxx} : \mathcal{M} &\rightarrow \mathbb{N} \quad \text{maxx}(\langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = x \quad \text{maxy} : \mathcal{M} \rightarrow \mathbb{N} \quad \text{maxy}(\langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = y \\
\circ : \mathcal{M} &\rightarrow \mathcal{M} \rightarrow \mathcal{M} \quad \langle l_a, C_a, \bar{d}_a, x_a, y_a \rangle_{\mathcal{M}} \circ \langle l_b, C_b, \bar{d}_b, x_b, y_b \rangle_{\mathcal{M}} = \\
&\quad \langle l_b, C_a +_{\mathcal{F}} C_b, \bar{d}_a \diamond \bar{d}_b, \max(x_a, x_b), \max(y_a, y_b) \rangle_{\mathcal{M}} \\
\text{adjustNest} : \mathbb{N} &\rightarrow \mathcal{M} \rightarrow \mathcal{M} \quad \text{adjustNest}(n, \langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = \langle l, C, \text{nest } n \bar{d}, x, y \rangle_{\mathcal{M}} \\
\text{adjustAlign} : \mathbb{N} &\rightarrow \mathcal{M} \rightarrow \mathcal{M} \quad \text{adjustAlign}(i, \langle l, C, \bar{d}, x, y \rangle_{\mathcal{M}}) = \langle l, C, \text{align } \bar{d}, x, \max(y, i) \rangle_{\mathcal{M}} \\
\leq : \mathcal{M} &\rightarrow \mathcal{M} \rightarrow \mathbb{B} \quad \langle l_a, C_a, \bar{d}_a, x, y \rangle_{\mathcal{M}} \leq \langle l_b, C_b, \bar{d}_b, x, y \rangle_{\mathcal{M}} = l_a \leq l_b \wedge C_a \leq_{\mathcal{F}} C_b
\end{aligned}
$$

Fig. 12. Measure and operations on measures

$$
\begin{array}{c}
\text{TEXTM} \frac{}{\langle \text{text } s, c, i \rangle \Downarrow_{\mathcal{M}} \langle c + |s|, \text{text}_{\mathcal{F}}(c, |s|), \text{text } s, c + |s|, i \rangle_{\mathcal{M}}} \\
\text{LINE} \frac{}{\langle \text{n1}, c, i \rangle \Downarrow_{\mathcal{M}} \langle i, \text{n1}_{\mathcal{F}} +_{\mathcal{F}} \text{text}_{\mathcal{F}}(0, i), \text{n1}, \max(c, i), i \rangle_{\mathcal{M}}} \quad \text{CONCAT} \frac{\langle \bar{d}_a, c, i \rangle \Downarrow_{\mathcal{M}} m_a \quad \langle \bar{d}_b, \text{last}(m_a), i \rangle \Downarrow_{\mathcal{M}} m_b}{\langle \bar{d}_a \diamond \bar{d}_b, c, i \rangle \Downarrow_{\mathcal{M}} m_a \circ m_b} \\
\text{NEST} \frac{\langle \bar{d}, c, i + n \rangle \Downarrow_{\mathcal{M}} m}{\langle \text{nest } n \bar{d}, c, i \rangle \Downarrow_{\mathcal{M}} \text{adjustNest}(n, m)} \quad \text{ALIGN} \frac{\langle \bar{d}, c, c \rangle \Downarrow_{\mathcal{M}} m}{\langle \text{align } \bar{d}, c, i \rangle \Downarrow_{\mathcal{M}} \text{adjustAlign}(i, m)}
\end{array}
$$

Fig. 13. Measure computation from a choiceless document in a printing context

costs to be used for pruning decisions. Since we wish to avoid full-blown rendering, we will instead operate on *measures* [Bernardy 2017c], which record the information about a choiceless document required for pruning without expensive rendering.

The workflow of $\Pi_e$ is shown in Figure 10, while Figure 11 shows how it relates to the evaluation of a document. The printer first resolves choices, with early pruning, to produce a small set of measures that contain the optimal measure. The set in particular forms a Pareto frontier in the cost and last line length trade-off (Section 6.2 and Section 6.3). We then pick the optimal measure from the set and render its choiceless document to produce an optimal layout.

In the rest of this section, every definition and theorem is implicitly parameterized by a cost factory $\mathcal{F}$ and a computation width limit $W$.

#### 6.2 Measure

As presented earlier, the resolving phase computes *measures*. Presented in Figure 12, a measure consists of five components: length of last line ($l$), cost ($C$), choiceless document ($\bar{d}$), max column position ($x$), and max indentation ($y$). We gray out the last two components because they are ghosted [Owicki and Gries 1976]: they are only needed for the correctness theorem, and not required in the actual implementation.

*Example 6.1.* Let $\bar{d}$ be the choiceless document in Example 3.1. With the cost factory in Example 3.4 and $w = 6$, the choiceless document is rendered at the column position 3 and indentation level 0 to the second layout in Figure 7, with the cost (8, 3). The column position of the last line is 1. The maximum column position attained is 10 (on the first line), and the maximum indentation level attained is 2. Thus, the computed measure is $\langle 1, (8, 3), \bar{d}, 10, 2 \rangle_{\mathcal{M}}$.

Figure 13 shows rules that define measure computation. The judgment $\langle d, c, i \rangle \Downarrow_{\mathcal{M}} m$ states that when we compute the measure of $\bar{d} \in \overline{\mathcal{D}}_c$ placed at the column position $c \in \mathbb{N}$ with indentation level $i \in \mathbb{N}$, the resulting measure is $m \in \mathcal{M}$. To simplify the core printer, we (temporarily) remove **flatten** from $\Sigma_e$. This allows us to eliminate the flattening mode parameter, which implicitly defaults to $\perp$. Toward the end of this section, we will show how to add support for **flatten** back.

The rules are largely standard. They reflect the actual rendering defined by $\Downarrow_{\mathcal{R}}$, and utilize the cost factory in a straightforward way. The rules use a helper operator function $\circ$ to concatenate two measures, and helper functions **adjustNest** and **adjustAlign** to construct a correct measure for **nest** and **align**. These functions are defined in Figure 12. Notably, the **LINE M ** rule creates a measure whose $\text{maxc}$ is $\max(c, i)$ because before placing the newline, the column position is $c$, and after placing the newline, the column position is $i$. The **ALIGN M ** rule creates a measure whose $\text{maxi}$ is $\max(y, i)$ where $y$ is obtained via the recursive computation. This is because the recursive computation discards the current indentation level, so we need to specifically record the information.

$\Downarrow_{\mathcal{M}}$ is deterministic and total. It is also correct with respect to $\Downarrow_{\mathcal{R}}$.

**THEOREM 6.2.** *For any $\bar{d} \in \overline{\mathcal{D}}_c$ and $c, i \in \mathbb{N}$, there exists a maximum indentation $y$ such that*

- if $\langle \bar{d}, c, i, \perp \rangle \Downarrow_{\mathcal{R}} [s]$, then $\langle \bar{d}, c, i \rangle \Downarrow_{\mathcal{M}} \langle c + |s|, \text{Cost}(c, [s]), \bar{d}, c + |s|, y \rangle_{\mathcal{M}}$.
- if $\langle \bar{d}, c, i, \perp \rangle \Downarrow_{\mathcal{R}} [s, s_1, \dots, s_n, t]$, then
  
  $\langle \bar{d}, c, i \rangle \Downarrow_{\mathcal{M}} \langle |t|, \text{Cost}(c, [s, s_1, \dots, s_n, t]), \bar{d}, \max(c + |s|, |s_1|, \dots, |s_n|, |t|), y \rangle_{\mathcal{M}}$

So far, we have only considered the measure computation for a choiceless document. When we take the choice operator into account, there could be multiple measures under the same printing context. The main operation that we can perform on these measures is finding domination $\leq$, also presented in Figure 12. $m_a \leq m_b$ when both the cost and the last length of $m_a$ are no worse than those of $m_b$. The fact that $m_a \leq m_b$ is useful because it allows us to prune $m_b$ away immediately.

#### 6.3 Measure Set

Resolving a document (in a printing context) produces a small set of measures. To accommodate taintedness mentioned in Section 3.3, Figure 14 defines a measure set to be either a non-empty Set of untainted measures where no measure dominates the other, or a Tainted singleton set of a promise $\hat{m}$ that can be forced to a measure. The Set, by definition, forms a Pareto frontier. To aid computation, we represent the Set with a list ordered by the cost in strict ascending order (and therefore the last length in strict descending order). We are able to do so because in a Pareto frontier, all last and cost values must be distinct.

The main operation that we can perform on measure sets is merging two measure sets ($\uplus$), shown in Figure 14, where we prefer a Set over a Tainted. The merge operation maintains the Pareto frontier invariant, by doing the merge in the style of the merge operation in merge sort, although the Pareto frontier merging can also prune measures away during the operation. One important “quirk” of this merge operation is that it is *left-biased* in the presence of taintedness. If two tainted measure sets are merged, the result is always the left one. This means the order of arguments to the merge operation is important, as we will see in the next subsections.

Other operations on measure sets which are used in subsequent sections are taint, lift, and dedup. taint taints a measure set. When tainting a Set, we choose to pick the first measure from the Set because it has the least cost, which is a greedy heuristic. lift adjusts measures in a measure set. Lastly, dedup prunes measures that are sorted by last in strictly decreasing order and by cost in non-strictly increasing order, so that the result conforms to the Pareto frontier invariant.

|  |  |
| --- | --- |
| Measure set $S \in \mathcal{S} ::= \text{Tainted}(\hat{m})$ | where $\hat{m}$ is a promise that can be forced to a measure |
| $\mid \text{Set}([m_1, \dots, m_n])$ | where $\text{last}(m_1) > \dots > \text{last}(m_n)$ and $\forall i \neq j, \neg(m_i \leq m_j \vee m_j \leq m_i)$ |
| $\text{taint} : \mathcal{S} \rightarrow \mathcal{S}$ | $\text{taint}(\text{Tainted}(m)) = \text{Tainted}(m)$<br>$\text{taint}(\text{Set}([m_0, m_1, \dots, m_n])) = \text{Tainted}(m_0)$ |
| $\text{lift} : \mathcal{S} \rightarrow (\mathcal{M} \rightarrow \mathcal{M}) \rightarrow \mathcal{S}$ | $\text{lift}(\text{Tainted}(m), f) = \text{Tainted}(f(m))$<br>$\text{lift}(\text{Set}([m_1, \dots, m_n]), f) = \text{Set}([f(m_1), \dots, f(m_n)])$ |
| $\text{dedup} : \vec{\mathcal{M}} \rightarrow \vec{\mathcal{M}}$ | $\text{dedup}([m, m', \dots, m_n]) = \text{dedup}([m', \dots, m_n])$ if $m' \leq m$<br>$\text{dedup}([m, m', \dots, m_n]) = [m] @ \text{dedup}([m', \dots, m_n])$ if $m' \not\leq m$<br>$\text{dedup}([m]) = [m]$ |
| $\uplus : \mathcal{S} \rightarrow \mathcal{S} \rightarrow \mathcal{S}$ | $S \uplus \text{Tainted}(m) = S$<br>$\text{Tainted}(m) \uplus \text{Set}([m_1, \dots, m_n]) = \text{Set}([m_1, \dots, m_n])$<br>$\text{Set}([m_1, \dots, m_n]) \uplus \text{Set}([m'_1, \dots, m'_{n'}]) = \text{Set}([m_1, \dots, m_n] \uplus [m'_1, \dots, m'_{n'}])$ |
| $\uplus : \vec{\mathcal{M}} \rightarrow \vec{\mathcal{M}} \rightarrow \vec{\mathcal{M}}$ | $[ ] \uplus [m_1, \dots, m_n] = [m_1, \dots, m_n]$<br>$[m_1, \dots, m_n] \uplus [ ] = [m_1, \dots, m_n]$<br>$[m_0, m_1, \dots, m_n] \uplus [m'_0, m'_1, \dots, m'_{n'}] = \begin{cases} [m_0, m_1, \dots, m_n] \uplus [m'_1, \dots, m'_{n'}] & \text{if } m_0 \leq m'_0 \\ [m_1, \dots, m_n] \uplus [m'_0, m'_1, \dots, m'_{n'}] & \text{if } m'_0 \leq m_0 \\ [m_0] @ ([m_1, \dots, m_n] \uplus [m'_0, m'_1, \dots, m'_{n'}]) & \text{if } \text{last}(m_0) > \text{last}(m'_0) \\ [m'_0] @ ([m_0, m_1, \dots, m_n] \uplus [m'_1, \dots, m'_{n'}]) & \text{otherwise} \end{cases}$ |

Fig. 14. Measure set and the merge operation on measure sets. @ denotes a list concatenation. We treat a promise $\hat{m}$ and a measure $m$ interchangeably, as they can be straightforwardly casted to each other.

#### 6.4 The Document Structure

Section 2.2 showed that we need to handle document sharing by treating the input document as a DAG. However, documents cannot be arbitrarily shared, as the following example shows:

*Example 6.3.* The following document $\text{mk}(n)$ has a DAG size of $O(n)$. However, resolving it necessitates $O(2^n)$ units of computation, as the printing contexts are all different. This is bad news because it means that resolving could take time exponential in the input size.

let rec mk (n : int) : doc =
if n = 0 then text "x"
else let shared = mk (n - 1) in shared <> shared

However, we argue that the above document is not *properly shared*, because the sub-documents are not shared *across choices*, which is how sharing is employed in practice. The corresponding properly shared document would have $O(2^n)$ DAG size, so $O(2^n)$ units of computation are still linear in the input size. To make this precise, we provide the following definitions:

*Definition 6.4.* Given a document $d \in \mathcal{D}_e$, $G(d)$ is a DAG rooted at $d$ whose edge in the graph connects a document to its direct subdocuments.

*Definition 6.5.* A document $d \in \mathcal{D}_e$ is *properly shared* if for any two vertices $d_a$ and $d_b$ in $G(d)$, if $p_1$ and $p_2$ are two distinct paths from $d_a$ to $d_b$, then there exists a common document $d'$ such that (1) $d'$ is a $\langle \rangle$; (2) $d'$ occurs in both $p_1$ and $p_2$; and (3) $d'$ is not $d_b$.

Figure 3c shows a properly shared document (assuming that $D$ is properly shared). It illustrates two paths where $d_a$ is the root node, $d_b$ is $D$, and $d'$ is $d_a$. In practice, non-properly shared documents can still be processed by $\Pi_e$, and in fact can even make resolving faster when a shared document is resolved under the same printing context. However, this shared document would be effectively

$$
\begin{array}{c}
\text{TEXTRSSSET} \frac{c + |s| \leq \mathcal{W} \quad i \leq \mathcal{W} \quad \langle \text{text } s, c, i \rangle \Downarrow_{\mathcal{M}} m}{\langle \text{text } s, c, i \rangle \Downarrow_{\text{RS}} \text{Set}([m])} \quad \text{LINERSSET} \frac{c \leq \mathcal{W} \quad i \leq \mathcal{W} \quad \langle \text{nl}, c, i \rangle \Downarrow_{\mathcal{M}} m}{\langle \text{nl}, c, i \rangle \Downarrow_{\text{RS}} \text{Set}([m])} \\
\text{TEXTRSTNT} \frac{c + |s| > \mathcal{W} \vee i > \mathcal{W} \quad \langle \text{text } s, c, i \rangle \Downarrow_{\mathcal{M}} m}{\langle \text{text } s, c, i \rangle \Downarrow_{\text{RS}} \text{Tainted}(m)} \quad \text{LINERSTNT} \frac{c > \mathcal{W} \vee i > \mathcal{W} \quad \langle \text{nl}, c, i \rangle \Downarrow_{\mathcal{M}} m}{\langle \text{nl}, c, i \rangle \Downarrow_{\text{RS}} \text{Tainted}(m)} \\
\text{NESTRS} \frac{\langle d, c, i + n \rangle \Downarrow_{\text{RS}} S}{\langle \text{nest } n \ d \ c, i \rangle \Downarrow_{\text{RS}} \text{lift}(S, \text{adjustNest}(n))} \quad \text{ALIGNRS} \frac{i \leq \mathcal{W} \quad \langle d, c, c \rangle \Downarrow_{\text{RS}} S}{\langle \text{align } d, c, i \rangle \Downarrow_{\text{RS}} \text{lift}(S, \text{adjustAlign}(i))} \\
\text{UNIONRS} \frac{\langle d_a, c, i \rangle \Downarrow_{\text{RS}} S_a \quad \langle d_b, c, i \rangle \Downarrow_{\text{RS}} S_b}{\langle d_a \langle \rangle d_b, c, i \rangle \Downarrow_{\text{RS}} S_a \uplus S_b} \quad \text{ALIGNRSTNT} \frac{i > \mathcal{W} \quad \langle d, c, c \rangle \Downarrow_{\text{RS}} S}{\langle \text{align } d, c, i \rangle \Downarrow_{\text{RS}} \text{lift}(\text{taint}(S), \text{adjustAlign}(i))} \\
\text{CONCATRS} \frac{\langle d_a, c, i \rangle \Downarrow_{\text{RS}} \text{Set}([m_1, \dots, m_n]) \quad \langle m_1, d_b, i \rangle \Downarrow_{\text{RSC}} S_1 \quad \dots \quad \langle m_n, d_b, i \rangle \Downarrow_{\text{RSC}} S_n}{\langle d_a \langle \rangle d_b, c, i \rangle \Downarrow_{\text{RS}} S_1 \uplus \dots \uplus S_n} \\
\text{CONCATRSTNT} \frac{\langle d_a, c, i \rangle \Downarrow_{\text{RS}} \text{Tainted}(m_a) \quad \langle d_b, \text{last}(m_a), i \rangle \Downarrow_{\text{RS}} S \quad \text{taint}(S) = \text{Tainted}(m_b)}{\langle d_a \langle \rangle d_b, c, i \rangle \Downarrow_{\text{RS}} \text{Tainted}(m_a \circ m_b)} \\
\hline
\text{RSCSET} \frac{\langle d_b, \text{last}(m_a), i \rangle \Downarrow_{\text{RS}} \text{Set}([m_1, \dots, m_n])}{\langle m_a, d_b, i \rangle \Downarrow_{\text{RSC}} \text{Set}(\text{dedup}([m_a \circ m_1, \dots, m_a \circ m_n]))} \quad \text{RSTTNT} \frac{\langle d_b, \text{last}(m_a), i \rangle \Downarrow_{\text{RS}} \text{Tainted}(m_b)}{\langle m_a, d_b, i \rangle \Downarrow_{\text{RSC}} \text{Tainted}(m_a \circ m_b)}
\end{array}
$$

Fig. 15. The resolver

duplicated when it is resolved in different contexts. For simplicity, we only consider properly shared documents as the input to $\Pi_e$ in this paper.

#### 6.5 The Resolver

We now formally define the core of $\Pi_e$, which is the resolver. It is described in Figure 15, which is a fusion of widening in Figure 8 and measure computation in Figure 13, with early pruning inherent in the merge operation and extra bookkeeping for taintedness. The judgment $\langle d, c, i \rangle \Downarrow_{\text{RS}} S$ states that a properly shared document $d \in \mathcal{D}_e$ at a column position $c \in \mathbb{N}$ with an indentation level $i \in \mathbb{N}$ resolves to a measure set $S$.

*Resolving Text.* If placing the text would exceed $\mathcal{W}$ or the indentation level is beyond $\mathcal{W}$, the TEXTRSTNT rule returns a Tainted. Otherwise, the TEXTRS rule returns a singleton Set.

*Resolving Newlines.* Resolving a **nl** is similar to resolving a **text**, but we only need to consider the current column position and indentation level, as resolving the newline does not change the column position. The LINERSTNT and LINERS rules cover these two cases.

*Resolving Nesting.* Resolving a **nest** is handled by the NESTRS rule, which recursively resolves its sub-document with the indentation level changed. The recursive resolving determines whether the measure set will be a Set or Tainted. In all cases, the result is adjusted to construct correct choiceless documents.

*Resolving Alignment.* Resolving an **align** is similar to resolving **nest**. However, because the recursive resolving discards the current indentation level, which could exceed $\mathcal{W}$, we need to taint the measure set when the indentation level is beyond $\mathcal{W}$. The ALIGNRSTNT rule handles such cases, and the ALIGNRS rule handles the other possibilities.

*Resolving Choices.* The UNIONRS rule recursively resolves its two sub-documents and then merges the resulting measure sets. As mentioned in Section 6.3, the merge operation is left-biased. Therefore, the left sub-document will be preferred over the right sub-document if exceeding $\mathcal{W}$ is unavoidable. It is possible to employ a heuristic to remove this bias, as discussed in Appendix C.

*Resolving Unaligned Concatenation.* Resolving a $\diamond$ is done through the CONCATRSTNT and CONCATRS rules, which handle the two possibilities of measure set types obtained from the left sub-document’s recursive resolving. Notably, the CONCATRS rule employs $\Downarrow_{\text{RSC}}$ to help us concatenate a left measure from the left measure set with a right measure set.

$\Downarrow_{\text{RS}}$ is deterministic and total. This allows us to define the top-level printer as $\Pi_e(d) = l$ where $\langle d, 0, 0 \rangle \Downarrow_{\text{RS}} [m_0, m_1, \dots, m_n]$ and $\langle \text{doc}(m_0), 0, 0, \perp \rangle \Downarrow_{\text{R}} l$, which consumes a properly shared document $d$, resolves it to a set of measures, picks the measure with the least cost, and renders the associated choiceless document to produce a layout. (Our implementation further fuses resolving and rendering together, as described in Appendix C.)

While the rules above are enough for correctness, implementing these rules requires further consideration. As we will see in Lemma 6.9, any resolving beyond $\mathcal{W}$ would eventually result in a tainted measure set. Hence, $\Pi_e$ should *immediately* delay the computation for any resolving beyond $\mathcal{W}$. $\Pi_e$ should also *memoize* the computation, so that on identical documents and printing contexts within $\mathcal{W}$, the result of the previous computation is reused.

We claim that $\Pi_e(d)$ consumes a properly shared document $d$ in $\Sigma_e$ and produces an optimal layout among $\text{eval}_e(d)$ within $\mathcal{W}$. We prove this claim in the next subsection.

#### 6.6 Correctness of \Pi_e

$\Downarrow_{\text{RS}}$ is correct with respect to $\Downarrow_{\mathcal{M}}$. Two theorems govern the correctness. The first theorem states that the core printer returns a measure set that contains a measure that is no worse than any measure within the computation width limit from all possible measures.

**THEOREM 6.6 (OPTIMALITY).** *For any $d \in \mathcal{D}_e$, $c \in \mathbb{N}$, $i \in \mathbb{N}$, if the following conditions hold*

- $\langle d, c, i \rangle \Downarrow_{\text{RS}} S$
- $d \Downarrow_{\mathcal{W}} \overline{D}$
- $\overline{d} \in \overline{D}$
- $\langle \overline{d}, c, i \rangle \Downarrow_{\mathcal{M}} m$
- $\text{maxx}(m) \leq \mathcal{W}$
- $\text{maxy}(m) \leq \mathcal{W}$

*then $S = \text{Set}([m_1, \dots, m_n])$. Furthermore, there exists $i$ such that $m_i \leq m$.*

The second theorem states that measures in the resulting measure set are valid.

**THEOREM 6.7 (VALIDITY).** *For any $d \in \mathcal{D}_e$, $c \in \mathbb{N}$, $i \in \mathbb{N}$ with $d \Downarrow_{\mathcal{W}} \overline{D}$, if $\langle d, c, i \rangle \Downarrow_{\text{RS}} \text{Set}([m_1, \dots, m_n])$, then for each $i$, there exists $\overline{d}$ such that $\overline{d} \in \overline{D}$ and $\langle \overline{d}, c, i \rangle \Downarrow_{\mathcal{M}} m_i$. Likewise, if $\langle d, c, i \rangle \Downarrow_{\text{RS}} \text{Tainted}(m_0)$, then there exists $\overline{d}$ such that $\overline{d} \in \overline{D}$ and $\langle \overline{d}, c, i \rangle \Downarrow_{\mathcal{M}} m_0$.*

The correctness of $\Pi_e$ follows immediately.

While the above theorems guarantee the correctness of the result that the printer produces, they do not guarantee efficiency. The following lemmas provide some properties of the printer that allow us to reason about its efficiency.

**LEMMA 6.8.** *For any $d \in \mathcal{D}_e$, $c \leq \mathcal{W}$, $i \leq \mathcal{W}$, if $\langle d, c, i \rangle \Downarrow_{\text{RS}} \text{Set}([m_1, \dots, m_n])$, then $n \leq \mathcal{W} + 1$.*

**LEMMA 6.9.** *For any $d \in \mathcal{D}_e$, if $c > \mathcal{W}$ or $i > \mathcal{W}$ and $\langle d, c, i \rangle \Downarrow_{\text{RS}} S$, then $S$ is a Tainted.*

We now informally prove the efficiency of $\Pi_e$ that we claimed in Section 1. The proof sketches are provided in Appendix B.

THEOREM 6.10. *The time complexity of $\Pi_e$ is $O(n^4)$ where $n$ is the DAG size of the document.*

THEOREM 6.11. *If a document $d$ is in the arbitrary-choice PPL, $\Pi_e$ can print $d$ in $O(n^3)$.*

#### 6.7 Handling Flattening

To support **flatten**, we make it a function that walks its sub-document and replaces all **nl** with **text** `"_"`. The walk is memoized and preserves the original identity of the document whenever possible (i.e. if nothing is flattened in sub-documents, then the document itself is returned unchanged without creating a new document). Thus, each document can be flattened at most once. This flattening creates at most $O(n)$ new documents without destroying the shared structure in the original document. We therefore achieve the functionality of **flatten** without affecting the time complexity of the printer.

### 7 IMPLEMENTATION

We implement $\Pi_e$ in OCaml and Racket. The printer, which we call PRETTYEXPRESSIVE, is further refined to be more efficient and practical. PRETTYEXPRESSIVE also includes more practical constructs that do not fit well to the formalism in this paper. We describe these refinements and additional constructs in Appendix C. The OCaml PRETTYEXPRESSIVE, as a reference implementation, is used for comparing against other printers in Section 8. The Racket PRETTYEXPRESSIVE has more features, and it has been used to implement a code formatter for the Racket programming language.

In these implementations, we extend the cost factory interface in Figure 6 so that $nl_{\mathcal{F}}$ is now a procedure that takes an indentation level $i$ as an input, and returns the cost of a newline along with $i$ indentation spaces, with a contract that $\forall i, i' \in \mathbb{N}. i \leq i' \rightarrow nl_{\mathcal{F}}(i) \leq_F nl_{\mathcal{F}}(i')$. That is, $nl_{\mathcal{F}}(i) = nl_{\mathcal{F} +_{\mathcal{F}}} \text{text}_{\mathcal{F}}(0, i)$ was not customizable before, but it is now customizable.[^12] PRETTYEXPRESSIVE then provides a pre-defined cost factory that is like Example 3.5, but with $nl_{\mathcal{F}}(i) = (0, 1)$.

### 8 EVALUATION

This section evaluates the performance and optimality of PRETTYEXPRESSIVE. The evaluation consists of two parts. First, we compare PRETTYEXPRESSIVE against Wadler/Leijen [2000] and Bernardy [2017b]’s printers, which are popular practical printers with capabilities from the traditional and arbitrary-choice PPLs. Second, we evaluate the Racket code formatter, which uses PRETTYEXPRESSIVE as its foundation. The evaluation aims to answer the following questions:

- (1) Does PRETTYEXPRESSIVE run fast in practice?
- (2) Does PRETTYEXPRESSIVE produce pretty layouts in practice?

All experiments are performed on an Apple M2 MacBook Pro with 16GB of RAM. We describe the experiments and benchmarks in Section 8.1 and Section 8.2, and discuss the results in Section 8.3.

#### 8.1 Comparison of Printers

We compare OCaml PRETTYEXPRESSIVE against the latest version (1.2.1) of Wadler/Leijen’s printer, and the “camera ready version” of Bernardy’s printer[^13]. This “camera ready version” consists of two printers: the “naïve” variant, which is presented in the paper, and the “practical” implementation, which has more features (such as unavoidable overflow handling) but suffers from exponential

[^12]: This change requires adjustments to many definitions and theorems, and we have done so for our Lean formalization. For example, to make Theorem 6.2 hold, we need to keep indentation spaces in the definition of layouts (Section 4.1).

[^13]: We also tried other versions of Bernardy’s printer, such as the commit 006fa0e8, which is the version right before the `<|>` operator was removed, and supposedly more optimized than the camera ready version. Unfortunately, we find that it has a severe performance deficiency. When attempting to replicate the experiments in Bernardy [2017c], we find that formatting the 10k-line-JSON file takes about 80 seconds, which is much slower than the 145 milliseconds reported in the paper.

Table 2. Comparison between PRETTYEXPRESSIVE in different configurations and other printers. For each printer and configuration, the first column reports the running time, and the second column reports the line count of the output layout. PRETTYEXPRESSIVE has an additional third column, where ✓ indicates that the rendering to the output layout fits $\mathcal{W}$ and ✗ indicates that the rendering to the output layout is tainted. “N/A” means the benchmark is not applicable. ⌘ indicates that running the benchmark exceeds the timeout of 60 seconds. “-” means the data is not collected. A grayed row indicates an output mismatch among the printers/configurations. The bolded line count signals that in our manual inspection, the associated layout is the prettiest.

| Benchmark | PRETTYEXPRESSIVE<br>default $\mathcal{W}$ | PRETTYEXPRESSIVE<br>(usually 100) | PRETTYEXPRESSIVE<br>$\mathcal{W} = 1000$ | PRETTYEXPRESSIVE<br>$\mathcal{W} = 1000$ | Wadler/Leijen | Wadler/Leijen | Bernardy<br>Naïve | Bernardy<br>Practical |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Concat10k | 0.000 s | 1 ✗ | 0.000 s | 1 ✗ | 0.002 s | 1 | N/A | 0.433 s |
| Concat50k | 0.002 s | 1 ✗ | 0.002 s | 1 ✗ | 0.011 s | 1 | N/A | 14.626 s |
| FillSep5k | 0.010 s | 668 ✓ | 0.010 s | 668 ✓ | 0.004 s | 668 | 3.097 s | 668 |
| FillSep50k | 0.190 s | 6834 ✓ | 0.190 s | 6834 ✓ | 0.035 s | 6834 | ⌘ | ⌘ |
| Flatten8k | 0.018 s | 7986 ✓ | 0.016 s | 7986 ✓ | 3.346 s | 7986 | N/A | N/A |
| Flatten16k | 0.036 s | 15986 ✓ | 0.037 s | 15986 ✓ | 18.816 s | 15986 | N/A | N/A |
| SExpFull15 | 3.027 s | 4107 ✓ | 5.437 s | 4107 ✓ | 0.045 s | 4107 | 0.647 s | 4107 |
| SExpFull16 | 5.255 s | 8246 ✓ | 14.232 s | 8246 ✓ | 0.091 s | 8246 | 1.251 s | 8246 |
| RandFit1k | 0.100 s | 629 ✓ | 0.229 s | 629 ✓ | 0.003 s | 943 | 0.048 s | 629 |
| RandFit10k | 1.047 s | 7861 ✓ | 4.420 s | 7861 ✓ | 0.037 s | 10459 | 0.534 s | 7861 |
| RandOver1k | 0.058 s | 1531 ✗ | 0.904 s | 1531 ✗ | 0.005 s | 1635 | N/A | 0.065 s |
| RandOver10k | 0.405 s | 15027 ✗ | 16.553 s | 15027 ✗ | 0.108 s | 16015 | N/A | 1.103 s |
| JSON1k | 0.001 s | 564 ✓ | 0.001 s | 564 ✓ | 0.003 s | 564 | N/A | 0.005 s |
| JSON10k | 0.007 s | 5712 ✓ | 0.007 s | 5712 ✓ | 0.018 s | 5712 | N/A | 0.097 s |
| JSONW | 0.001 s | 721 ✗ | 0.001 s | 721 ✓ | 0.002 s | 721 | N/A | 0.005 s |

Table 3. The code formatter benchmarks. The table is in the same format as the PRETTYEXPRESSIVE column in Table 2.

| Benchmark | $\mathcal{W} = 100$ | $\mathcal{W} = 100$ | $\mathcal{W} = 1000$ | $\mathcal{W} = 1000$ | Benchmark | $\mathcal{W} = 100$ | $\mathcal{W} = 100$ | $\mathcal{W} = 1000$ | $\mathcal{W} = 1000$ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| class-internal | 0.325 s | 5750 ✗ | 0.307 s | 5751 ✓ | list | 0.025 s | 993 ✓ | 0.025 s | 993 ✓ |
| xform | 0.372 s | 5154 ✗ | 0.417 s | 5154 ✓ | hash | 0.020 s | 83 ✓ | 0.020 s | 83 ✓ |

time complexity when the DAG structure unfolds, as discussed in Section 2. We manually remove the capability to customize the width limit from the latter to avoid the issue. Both variants are used for the evaluation, since the naïve variant does not have necessary features for some benchmarks.

PRETTYEXPRESSIVE is instantiated with the cost factory in Section 7, with a page width limit of 80 (unless indicated otherwise). We run PRETTYEXPRESSIVE twice with different computation width limits (once with $\mathcal{W} = 100$, unless indicated otherwise, and once with $\mathcal{W} = 1000$), in order to observe the effect of the tainting system and how it affects the performance.

The benchmarks (Table 2) are mostly taken from Bernardy [2017c], and we add a few more to test basic constructs. While Leijen’s printer is expressive enough to handle all benchmarks (due to the inclusion of align to support aligned concatenation in addition to constructs from the traditional PPL), Bernardy’s printers are not applicable to benchmarks that require constructs from the traditional PPL. Furthermore, Bernardy’s naïve printer is not applicable to benchmarks that require extra features like unavoidable overflow handling.

In more detail, the benchmarks test the following kinds of documents:

**Concat** benchmarks test a long chain of concatenations, which are identified by Peyton-Jones [1997] as a source of quadratic time complexity in Hughes’ printer.

**FillSep** benchmarks test the fillSep construct (also known as fill), which performs word wrapping.

**Flatten** benchmarks test repeated flattening, as shown in Figure 17 in Appendix A.

**SExpFull** benchmarks are the last two data points from the “full tree” benchmark in [Bernardy [2017c]](#)’s paper. They create complete binary trees and print them as S-expressions.

**RandFit** benchmarks [[Bernardy 2017c](#)] are similar to SExpFull, but use random Dyck paths to generate random trees and filter only those that fit within the page width limit.

**RandOver** benchmarks are like RandFit with the opposite filtering.

**JSON** benchmarks are also from [Bernardy [2017c]](#)’s paper. They format large JSON files.

**JSONW** benchmark is the same as JSON1k but with a page width limit of 50 instead of 80, and we further adjust PRETTYEXPRESSIVE’s default $\mathcal{W}$ from 100 to 60 to test the tainting system.

#### 8.2 Racket Code Formatter

We evaluate the effectiveness of a Racket code formatter that uses the Racket PRETTYEXPRESSIVE as its foundation. Racket [[Felleisen et al. 2018](#)] is a programmable programming language. Its main syntax is S-expression based, but this can be customized via its `#lang` protocol to read an arbitrary syntax. Even in the S-expression syntax, users can define custom forms via the macro system. Our long-term plan for the code formatter is to make it extensible to support any syntax and custom forms. PRETTYEXPRESSIVE is thus a natural choice as a foundational printer, due to its expressiveness.

The code formatter currently supports only S-expression formatting. However, the task is already challenging. While the S-expression syntax may look simple and uniform, Racket users employ a variety of styles for different forms to make them look distinctive in order to improve readability. Each function application, for example, has three possible styles (while most languages have two function application styles). The search space of the code formatter is thus quite large.

The benchmarks ([Table 3](#)) consist of files of different sizes from the Racket language codebase[^14]. `class-internal` and `xform` are the two largest files. We use the code formatter to format these files with the page width limit of 80. We run the code formatter twice, once with $\mathcal{W} = 100$ and once with $\mathcal{W} = 1000$.

#### 8.3 Results

*Performance.* The benchmarking results in [Table 2](#) and [Table 3](#) show that overall, PRETTYEXPRESSIVE is sufficiently fast in practice. While not the fastest, it can process large, practical workloads `class-internal` and `xform` under a second. Furthermore, it provides a performance guarantee even on tricky inputs. The same is not true for other printers. The Flatten benchmarks work very poorly for Wadler’s printer, and the FillSep benchmarks work very poorly for Bernardy’s printer. Interestingly, Bernardy’s naïve printer is faster than its practical variant, even though the latter is more optimized; this is due to the extra features that the practical printer needs to support. PRETTYEXPRESSIVE, by contrast, is set to support these features from the start.

We note two interesting observations of PRETTYEXPRESSIVE. First, it performs poorly on SExpFull relative to other printers. This is due to the memory pressure from memoization. Better engineering effort may be able to alleviate this issue. Second, although the time complexity of $\Pi_c$ is $O(n^4)$, this worst case behavior happens only if Pareto frontiers are always full. In practice, this is not the case[^15], as evidenced by the fact that increasing $\mathcal{W}$ tenfold does not multiply the running time by $10^4$. On the contrary, increasing $\mathcal{W}$ does not affect the running time at all on most benchmarks.

*Optimality.* We find that PRETTYEXPRESSIVE is the prettiest compared to others, offering high quality output when we use the cost factory described in [Section 7](#). [Table 2](#) shows (via line count) that the output layouts in many benchmarks agree in all printers. The exceptions are RandFit,

[^14]: [https://github.com/racket/racket/tree/master/racket/collects](https://github.com/racket/racket/tree/master/racket/collects) at commit 4fla2bd4

[^15]: This observation also applies to Bernardy’s printers, which are also based on Pareto frontiers.

RandOver, and JSONW benchmarks. Upon manual inspection, we find that the layouts produced by PRETTYEXPRESSIVE are better. JSONW and RandOver are cases where there is an unavoidable overflow, causing Bernardy’s printer to overflow more than necessary. Figure 18 in Appendix A demonstrates this problem. RandFit and RandOver are cases where the greedy minimization and the align construct in Leijen’s printer interact poorly, as discussed in Bernardy [2017c]’s paper.

It should also be noted that neither Leijen’s nor Bernardy’s printers support custom optimality objectives, as their optimality objectives are integral to their algorithms. PRETTYEXPRESSIVE, by contrast, allows users to customize optimality objective via the cost factory.

Lastly, we evaluate the effectiveness of the tainting system. For almost every benchmark that has a tainted rendering ($\mathbf{X}$) with the default $\mathcal{W}$, we find that using $\mathcal{W} = 1000$ in an attempt to avoid taintedness[^16] yields the same result, confirming the optimality of the output layout. The only exception is the class-internal benchmark in Table 3, for which the output layouts are different in one line and otherwise identical, because the greedy heuristic in the taint operation prunes the optimal choice away. This demonstrates that despite being tainted, and thus no longer guaranteed to be optimal, the output layout is still reasonable (at least with respect to the cost factory that we employ and the heuristic to avoid bias described in Appendix C).

### 9 CONCLUSION

We have described $\Pi_e$, an expressive printer that supports a variety of optimality objectives and is practically efficient. We developed a framework for reasoning about the expressiveness of PPLs, and we used this framework to guide the design of the PPL that $\Pi_e$ targets. By surveying existing pretty printers, we have shown that $\Pi_e$ is well-placed in the design space of printers. $\Pi_e$ is proven correct in the Lean theorem prover and implemented as a practical printer PRETTYEXPRESSIVE, which powers a real-world code formatter for the Racket programming language. Our results show that PRETTYEXPRESSIVE (and $\Pi_e$) is both pretty and fast.

### DATA-AVAILABILITY STATEMENT

The latest version of the Racket PRETTYEXPRESSIVE[^17] and the Racket code formatter[^18] are available on GitHub. The main artifact, which consists of the above softwares and:

- the Lean formalization (Sections 4 and 6)
- the Rosette proofs (Section 3)
- the OCaml PRETTYEXPRESSIVE (Section 7)
- the benchmarks to reproduce our evaluation (Section 8)

is available on Docker,[^19] with its source on GitHub.[^20] A snapshot of the artifact is available on Zenodo [Porncharoenwase et al. 2023].

### ACKNOWLEDGMENTS

We are thankful to the anonymous reviewers and the anonymous artifact reviewers for their very helpful feedback. This work is supported by the National Science Foundation under Grant Nos. CF-1651225, CCF-1836724, CNS-1844807, and by a gift from the VMware University Research Fund.

[^16]: Therefore, the Concat benchmarks do not count, since they are still tainted afterwards. The benchmarks are not interesting anyway, since there is no choice in the documents, so the output layouts are always optimal.

[^17]: [https://github.com/sorawee/pretty-expressive](https://github.com/sorawee/pretty-expressive)

[^18]: [https://github.com/sorawee/fmt](https://github.com/sorawee/fmt)

[^19]: [https://hub.docker.com/repository/docker/sorawee/pretty-expressive-oopsla23-artifact/](https://hub.docker.com/repository/docker/sorawee/pretty-expressive-oopsla23-artifact/)

[^20]: [https://github.com/sorawee/pretty-expressive-oopsla23-artifact](https://github.com/sorawee/pretty-expressive-oopsla23-artifact)

### A AN ANALYSIS OF PRINTERS

group (text "AAA" <> nl) <>
nest 5 (group (text "B" <> nl <>
text "B" <> nl <> text "B")))

1 AAA
2 B B B

1 AAA
2 B
3 B

Fig. 16. A document in the traditional PPL and two of its corresponding layouts. Under the width limit of 5, the first layout is optimal—it does not overflow and occupies a minimal number of lines. By contrast, the second layout, which is produced by Wadler's printer, overflows and does not occupy a minimal number of lines.

let rec quadratic (n : int): doc =
if n = 0 then text "line"
else group (quadratic (n - 1) <> nl <> text "line")

Fig. 17. The function quadratic generates a document of size $O(n)$ that Wadler's algorithm takes $O(n^2)$ to print at any width limit, due to repeated flattening.

text "xxxxxxx" <<$>
((text "aaa" <<+> text "bbb") <<|>
(text "aaa" <<$> text "bbb"))

1 xxxxxx
2 aaa
3 bbb

1 xxxxxx
2 aaabb

Fig. 18. A document in the arbitrary-choice PPL and two of its corresponding layouts. Under the width limit of 5, the first layout minimally overflows. By contrast, the second layout, which is produced by Bernardy's practical implementation, overflows more than necessary.

let rec mk (n : int): doc =
if n = 0 then text "X" <<|> text "XX"
else let subdoc = mk (n - 1) in (chr n <<+> subdoc <<+> chr n) <<|> subdoc

(a) The function mk generates a document whose DAG size is $O(n)$. $\text{chr}(n)$ denotes a **text** whose content is a string of length one that contains the $n$th character.

$$
\begin{aligned}
C'[D_n, Z_{[1]}] &= C'[\text{chr}(n) \leftrightarrow D_{n-1} \leftrightarrow \text{chr}(n), Z_{[1]}] \langle | \rangle C'[D_{n-1}, Z_{[1]}] \\
&= C'[\text{chr}(n), C'[D_{n-1}, C'[\text{chr}(n), Z_{[1]}]]] \langle | \rangle C'[D_{n-1}, Z_{[1]}] \\
&= C'[\text{chr}(n), C'[D_{n-1}, Z_{[n]}]] \langle | \rangle C'[D_{n-1}, Z_{[1]}] \\
C'[D_{n-1}, Z_{[1]}] &= C'[\text{chr}(n-1), C'[D_{n-2}, Z_{[n-1]}]] \langle | \rangle C'[D_{n-2}, Z_{[1]}] \\
C'[D_{n-1}, Z_{[n]}] &= C'[\text{chr}(n-1), C'[D_{n-2}, C'[\text{chr}(n-1), Z_{[n]}]]] \langle | \rangle C'[D_{n-2}, Z_{[n]}] \\
&= C'[\text{chr}(n-1), C'[D_{n-2}, Z_{[n-1,n]}]] \langle | \rangle C'[D_{n-2}, Z_{[n]}]
\end{aligned}
$$

(b) Let $D_n$ denote $\text{mk}(n)$. Yelland's $C'$ function would transform the original document $D_n$ into a restricted document where every aligned concatenation has a **text** as its left subdocument. However, the above derivation shows that the transformation has a combinatorial explosion. Define $Z_{[1]}$ to be $\blacksquare$ in Yelland's paper and $Z_{[x, x_1, \dots, x_n]}$ to be $C'[\text{chr}(x), Z_{[x_1, \dots, x_n]}]$. The derivation shows that $D_{n-k}$ is recursively transformed in $2^k$ different contexts.

Fig. 19. A family of documents that illustrates how the transformation $C'$ in Yelland's algorithm does not necessarily preserve the sharing structure in the original document.

(* make an empty document of size n; n >= 1 *)
let rec make_dummy (n : int): doc =
if n = 1 then text ""
else text "" <-> make_dummy (n - 1)

(* make n lines; n >= 1 *)
let rec make_lines (n : int): doc =
if n = 1 then text ""
else text "" <-> make_lines (n - 1)

(* nth triangle number *)
let tri (n : int): int = n * (n + 1) / 2

let make_choices (k : int): doc =
let rec loop (i : int): doc =
let doc =
(make_lines i) <->
text (String.make (tri (k - i + 1)) 'a')
in if i = 1 then doc else doc <-> loop (i - 1)
in loop k

let rec example (k : int): doc =
let dummy = make_dummy (k * k) in
let giant = make_choices k in
dummy <-> giant

(a) The function `example` produces a document that triggers the worst-case time complexity of Yelland’s algorithm (that we are aware of). For a fixed $k$, `giant` is a document with $k$ choices, where the $i$-th choice has $i$ lines and $\text{tri}(k - i + 1)$ characters ($\text{tri}$ is the triangle number function). Thus, its document tree size is $O(k^2)$. By concatenating `giant` with `dummy`, which is an “empty” document of size $O(k^2)$, the total document tree size is still $O(k^2)$. `giant` is designed so that it has $k$ segmented linear cost functions. Thus, the aligned concatenation of `dummy` and `giant` takes $O(k^3)$. By normalizing the document size to $\hat{n}$, we obtain that the time complexity of the printer is $O(\hat{n}^{3/2})$.

*[Figure: Figure 20(b): A plot of the piecewise linear cost function for giant with k = 10. The x-axis is 'column position' (0 to 10) and the y-axis is 'cost' (0 to 60). The plot shows 10 red dots representing the cost at each column position. A blue line connects these dots, forming a piecewise linear function. Several yellow lines represent the individual cost functions for each choice, which are linear and intersect at the red dots. The blue line is the minimum of these yellow lines.]*

(b) A plot of the piecewise linear cost function (lines along the red dots) for `giant` in Figure 20a with $k = 10$. The x-axis is column positions at which `giant` will be printed. The y-axis is cost of `giant`. The plot consists of $O(k)$ segmented cost functions, where each segment is a linear function. For simplicity, we assume that (1) the page width limit is 0; (2) there is no cost for newlines; and (3) the cost for each character past the page width limit is 1. Let $\bar{d}_i$ be the $i$-th choice in `giant`. The cost function for $\bar{d}_i$ then is $C_{\bar{d}_i}(c) = ic + \text{tri}(k - i + 1)$. These cost functions intersect at $c = 2, \dots, k$. Thus, the cost function for `giant` is unable to prune any segments away.

Fig. 20. In Yelland’s algorithm, every choiceless document (in the arbitrary-choice PPL) $\bar{d}$ has an associated *piecewise linear* cost function $C_{\bar{d}}$, where $C_{\bar{d}}(c)$ determines the cost of $\bar{d}$’s rendered layout at the column position $c$. A general document $d$ similarly has an associated piecewise linear cost function $C_d$, which takes the minimum of the cost functions from all choiceless documents that $d$ generates. The algorithm appears to be efficient at first glance, since taking the minimum can prune away many segmented linear cost functions. However, we are able to construct a document `giant` of size $O(\hat{n})$ whose cost function has $O(\sqrt{\hat{n}})$ segmented linear cost functions, where $\hat{n}$ is the tree size of the document. As the time complexity of the printer is $O(\hat{n}M)$ where $M$ is the maximum number of piecewise linear cost functions in a cost function, we obtain $O(\hat{n}^{3/2})$.

### B SELECTED PROOF SKETCHES

LEMMA 5.2. *The arbitrary-choice PPL and $\Sigma_e$ are functionally complete.*

PROOF SKETCH. For the arbitrary-choice PPL with the evaluation function $\text{eval}(\cdot)$, let $L$ be any non-empty set of layouts. For each $l_i \in L$ where $l_i = [s_1^i, \dots, s_{|l_i|}^i]$, we construct $d_i$ to be `text s 1 i <-> ... <-> text s |l i |} `. Finally, we construct $d$ to be `d 1 <-> ... <-> d |L|} `. We can see that $\text{eval}(d) = L$. The proof for $\Sigma_e$ PPL is similar, but we replace `a <-> b` with `a <-> nl <-> b`. $\square$

LEMMA 5.3. *The traditional PPL is not functionally complete.*

PROOF SKETCH. It is not possible to construct a document in the traditional PPL that evaluates to the set of layouts $E = \{["a"], ["b"]\}$. To see why, let $\text{rmspace} : \mathcal{L} \rightarrow \text{Str}$ be a function that joins all lines in a layout into a single line, with all whitespaces removed, and lift $\text{rmspace}$ to work on a set of layouts (i.e., $\text{rmspace}(L) = \{\text{rmspace}(l) : l \in L\}$). Let $\text{eval}(\cdot)$ be the evaluation function for the traditional PPL. We can prove by induction that $\text{rmspace}(\text{eval}(d))$ is a singleton set for any document $d$. In other words, all layouts in $\text{eval}(d)$ are the same, modulo whitespaces. However, $\text{rmspace}(E) = \{"a", "b"\}$, which is not a singleton set. Hence, by congruence, no document can render to $E$.

Note that there are other sets of layouts that are the same modulo whitespaces, but can't be evaluated to by the traditional PPL. An example is *synchronized* differences of spacing across multiple lines. $\square$

LEMMA 5.4. *For each construct $\mathbf{F}$ in $\{\text{text}, \diamond, \text{nl}, \langle \rangle\}$, $\Sigma_e$ without $\mathbf{F}$ is not functionally complete.*

PROOF SKETCH. It is not possible to construct a document in each language in question that evaluates to the following set of layouts

$\Sigma_e$ without **text**. $\{["a"]\}$, because all we can produce is whitespaces.

$\Sigma_e$ without **$\diamond$**. $\{["a", "b", "c"]\}$, because all we can produce is at most two lines.

$\Sigma_e$ without **nl**. $\{["a", "b"]\}$, because all we can produce is a single line.

$\Sigma_e$ without **$\langle \rangle$**. $\{["a"], ["b"]\}$, because all we can produce is a single layout. $\square$

THEOREM 5.12. *Every construct in the traditional and arbitrary-choice PPLs is definable in $\Sigma_e$.*

PROOF SKETCH. The following syntactic abstractions can be used to define the constructs:

- **group** is definable by $\mathbf{M}(\alpha_1) = \alpha_1 \langle \rangle \text{ flatten } \alpha_1$
- **$\langle \rangle$** is definable by $\mathbf{M}(\alpha_1, \alpha_2) = \alpha_1 \diamond \text{ nl } \diamond \alpha_2$.
- **$\langle \rangle$** is definable by $\mathbf{M}(\alpha_1, \alpha_2) = \alpha_1 \diamond \text{ align } \alpha_2$.

The rest of the constructs are already in $\Sigma_e$. $\square$

THEOREM 5.16. *Given a PPL $\Sigma$ and a construct $\mathbf{F}$, if there exists two documents $d_1$ and $d_2$ in $\Sigma$ and a relation $R$ such that $E_R^\Sigma(d_1, d_2)$, but $\neg E_R^{\Sigma \cup \{\mathbf{F}\}}(d_1, d_2)$, then $\mathbf{F}$ is not definable in $\Sigma$.*

PROOF SKETCH. Let $\text{eval}_a(\cdot)$ and $\text{eval}_b(\cdot)$ denote the evaluation functions for $\Sigma$ and $\Sigma \cup \{\mathbf{F}\}$, respectively. We prove the contraposition. Assuming that $\mathbf{F}$ is definable in $\Sigma$, we need to prove that for any $d_1, d_2$, and $R$, $E_R^\Sigma(d_1, d_2)$ implies $E_R^{\Sigma \cup \{\mathbf{F}\}}(d_1, d_2)$. Let $d_1, d_2$, and $R$ be arbitrary. We suppose that for all context $C$ in $\Sigma$, $R(\text{eval}_a(C(d_1)), \text{eval}_a(C(d_2)))$ holds, and need to prove that for all context $C$ in $\Sigma \cup \{\mathbf{F}\}$, $R(\text{eval}_b(C(d_1)), \text{eval}_b(C(d_2)))$ holds.

Let $C$ be a context in $\Sigma \cup \{\mathbf{F}\}$. Because $\mathbf{F}$ is definable in $\Sigma$, we can perform a syntactic expansion on $C$ to obtain a context $C^*$ in $\Sigma$ such that $\text{eval}_a(C^*(d)) = \text{eval}_b(C(d))$ for all document $d$ in $\Sigma$. Hence, it suffices to prove that $R(\text{eval}_a(C^*(d_1)), \text{eval}_a(C^*(d_2)))$ holds, but this is our hypothesis (instantiated with $C^*$). $\square$

THEOREM 5.17. *The following is true:*

- **$\diamond$** is not definable in the arbitrary-choice PPL.
- **nest** is not definable in the arbitrary-choice PPL.
- **group** is not definable in the arbitrary-choice PPL.
- **$\langle \rangle$** is not definable in the traditional PPL.

**PROOF SKETCH.** In each proof, we need to show that $\mathbf{F}$ is not definable in $\Sigma$, where $\mathbf{F}$ and $\Sigma$ are the construct and the PPL in question. We do so by providing a counterexample, which consists of documents $d_1$ and $d_2$, and the relation $R$. By induction, it can be shown that $E_R^\Sigma(d_1, d_2)$. We will further provide a counterexample context to show that $\neg E_R^{\Sigma \cup \{\mathbf{F}\}}(d_1, d_2)$. By [Theorem 5.16](#), this suffices to show that $\mathbf{F}$ is not definable in $\Sigma$.

$\diamond$ *is not definable in the arbitrary-choice PPL.* Given $\text{maxWidth}$ from [Example 5.15](#), the counterexample is $d_1 = \text{text "a"} \diamond \text{text "bb"}$, $d_2 = \text{text "aa"} \diamond \text{text "bb"}$, and $R = \{(L_a, L_b) : \text{maxWidth}(L_a) = \text{maxWidth}(L_b)\}$. In particular, with $C(\alpha) = \text{text "c"} \diamond \alpha$, we have that $\text{maxWidth}(\text{eval}(d_1)) = \{2\}$, but $\text{maxWidth}(\text{eval}(d_2)) = \{3\}$.

*nest* *is not definable in the arbitrary-choice PPL.* Given $\text{maxWidth}$ from [Example 5.15](#), the counterexample is $d_1 = \text{text "bb"} \diamond \text{text "a"}$, $d_2 = \text{text "cc"} \diamond \text{text "bb"} \diamond \text{text "a"}$, and $R = \{(L_a, L_b) : \text{maxWidth}(L_a) = \text{maxWidth}(L_b)\}$. In particular, with $C(\alpha) = \text{nest } 1 \alpha$, we have that $\text{maxWidth}(\text{eval}(d_1)) = \{2\}$, but $\text{maxWidth}(\text{eval}(d_2)) = \{3\}$.

*group* *is not definable in the arbitrary-choice PPL.* Let $\text{maxa} : \mathcal{L} \rightarrow \mathbb{N}$ be a function that finds the maximum number of the character "a" in lines of the layout, and lift $\text{maxa}$ to work on a set of layouts. The counterexample is $d_1 = \text{text "a"} \diamond \text{text "a"}$, $d_2 = \text{text "a"} \diamond \text{text "a"} \diamond \text{text "a"}$, and $R = \{(L_a, L_b) : \text{maxa}(L_a) = \text{maxa}(L_b)\}$. In particular, with $C(\alpha) = \text{group } \alpha$, we have that $\text{maxa}(\text{eval}(d_1)) = \{1, 2\}$, but $\text{maxa}(\text{eval}(d_2)) = \{1, 3\}$.

$\leftrightarrow$ *is not definable in the traditional PPL.* Let $\text{spaces} : \mathcal{L} \rightarrow \mathbb{N}$ be a function that counts the number of spaces in a layout (not counting newlines), and lift $\text{spaces}$ to work on a set of layouts. The counterexample is $d_1 = \text{text "a"}$, $d_2 = \text{text "aa"}$, and $R = \{(L_a, L_b) : \text{spaces}(L_a) = \text{spaces}(L_b)\}$. In particular, with $C(\alpha) = \alpha \leftrightarrow (\text{text "b"} \diamond \text{nl} \diamond \text{text "c"})$, we have that $\text{spaces}(\text{eval}(d_1)) = \{1\}$, but $\text{spaces}(\text{eval}(d_2)) = \{2\}$. $\square$

**LEMMA 5.18.** *If $\Sigma$ is not functionally complete, but $\Sigma \cup \{\mathbf{C}\}$ is, then $\mathbf{C}$ is not definable in $\Sigma$.*

**PROOF SKETCH.** Because $\Sigma$ is not functionally complete, there is a set of layouts $L^*$ that can't be evaluated to by any document in $\Sigma$. Since $\Sigma \cup \{\mathbf{C}\}$ is functionally complete, there is a document $d^*$ (which necessarily contains $\mathbf{C}$) that evaluates to $L^*$. Let $d_1$ and $d_2$ be any document in $\Sigma$, and $R = (2^{\mathcal{L}} \times 2^{\mathcal{L}}) \setminus \{(L^*, L^*)\}$. Then $E_R^\Sigma(d_1, d_2)$ holds trivially. However, with $C(\alpha) = d^*$, we have that $\neg E_R^{\Sigma \cup \{\mathbf{C}\}}(d_1, d_2)$. This concludes the proof that $\mathbf{C}$ is not definable in $\Sigma$. $\square$

**THEOREM 5.19.** *For any construct $\mathbf{F}$ of $\Sigma_e$, $\mathbf{F}$ is not definable in $\Sigma_e \setminus \{\mathbf{F}\}$.*

**PROOF SKETCH.** The proofs for **text**, **nl**, $\diamond$, and $\langle | \rangle$ are applications of [Lemma 5.2](#), [Lemma 5.4](#), and [Lemma 5.18](#). The proofs for **nest**, **flatten**, and **align** are just like how we proved [Theorem 5.17](#) for **nest**, **group**, and $\leftrightarrow$. $\square$

**THEOREM 6.10.** *The time complexity of $\Pi_e$ is $O(n^{\mathcal{W}^4})$ where $n$ is the DAG size of the document.*

**PROOF SKETCH.** The most expensive operation in the printer is concatenation (via **CONCATRSSSET**). The operation resolves the left sub-document, resulting in a measure set whose size is at most $\mathcal{W}$ according to [Lemma 6.8](#). It then resolves the right sub-document in at most $\mathcal{W}$ different contexts. Thus, there are at most $\mathcal{W}^2$ different measures from the right sub-document that the printer needs to concatenate and prune.

Consider $\langle d, c, i \rangle \Downarrow_{\text{RSS}} S$. $d$ can range over $n$ different values. $c$ and $i$ can range over $\mathcal{W}$ different values that are under $\mathcal{W}$. Hence, there are $O(n^{\mathcal{W}^2})$ different contexts under the computation width limit. Multiplying this with the maximum units of computation in the previous paragraph, we obtain that the time complexity due to resolving within $\mathcal{W}$ is $O(n\mathcal{W}^4)$, assuming that the resolver reuses memoized measure sets under the same context.

When $d$ is printed beyond $\mathcal{W}$, however, it can be fully resolved at most once, because:

- (1) While we would resolve both sub-documents of choice nodes, they would be all tainted, due to [Lemma 6.9](#). Because all tainted measure sets are promises, all computations are delayed. The merge operation then chooses only one tainted measure set as the result, discarding the other one.
- (2) The document is properly shared, so under a given path, a document is encountered at most once.

As a result, the time complexity due to printing over $\mathcal{W}$ is simply $O(n)$. Combining both parts, we obtain that the time complexity of $\Pi_e$ is $O(n\mathcal{W}^4)$. $\square$

**THEOREM 6.11.** *If a document $d$ is in the arbitrary-choice PPL, $\Pi_e$ can print $d$ in $O(n\mathcal{W}^3)$.*

**PROOF SKETCH.** In the arbitrary-choice PPL, $c = i$ is (mostly) maintained throughout the printing. Hence, there is one less dimension to consider, leading to the time complexity of $O(n\mathcal{W}^3)$. $\square$

### C DISCUSSION

In this section, we broadly discuss the design of our work.

#### C.1 Additional Constructs

PRETTYEXPRESSIVE supports additional constructs **fail**, **newline**, and **reset**. The Racket PRETTYPEX- PRESSIVE further supports additional constructs **full** and **cost**. These constructs are out of scope for the paper, and we leave their formalization as future work.

*Failure.* **fail** widens to the empty set, thus introducing the possibility that a printing could fail. Furthermore, it is the identity for the operation $\langle \rangle$. **fail** makes $\Sigma_e$ more expressive because it is impossible to make a document in $\Sigma_e$ evaluate to the empty set. In this sense, it could be said that $\Sigma_e$ is not truly “functionally complete,” but $\Sigma_e$ with **fail** is. Supporting **fail** can be done via rewriting rules: every document with **fail** can be normalized to a semantically-equivalent document without **fail**, or to a single **fail**. Hence, there is no need to modify the core printer to support the construct.

*Generalized Newlines.* **newline** $m$ is a straightforward generalization of **nl** so that flattening it can result in other possibilities besides a single space. When $m$ is **Some** $s$, the flattened result is **text** $s$. When $m$ is **None**, the flattened result is **fail**. With this construct:

- **nl** is definable with **newline** (**Some** “_”).
- **break** from [Leijen [2000]](#)’s printer is definable with **newline** (**Some** “”).
- **hard_nl** is definable with **newline** **None**. With **hard_nl**, **singleLine** from [Bernardy [2017b]](#)’s practical printer is definable with **flatten**, given that the vertical concatenation uses **hard_nl** for entering a newline.

*Reset.* **reset** $d$ resets the indentation level to 0 for $d$. This is useful for formatting multiline comments and here-string.

*Fullness.* **full** $d$ marks $d$ as *full*, which means there must be no more text after it in the same line. The construct is especially useful for formatting line comments, as it is illegal to put a piece of code after a line comment. A simpler variant of **full** is also implemented in Yelland’s printer for the R code formatter [[Yelland 2015]](#). Unlike other extensions, which can be supported without significant changes to the core printer modification, **full** requires more involved changes.

- The measure set definition is now required to recognize the empty set (where we prefer a tainted measure set over the empty set).
- The resolver would consume two additional boolean arguments, which indicate the fullness status before and after the document.
- Merging two tainted measure sets must now keep both tainted measure sets, and we may need to try both if the first one resolves to the empty set.

To keep the time complexity of the printer $O(nW^4)$, we rely on the fact that “emptiness” in resolving (that is, resolving to the empty set) is independent from column positions and indentation levels. Thus, even though we now need to try many tainted measure sets, a document can be tried at most four times, which bounds the time complexity.

Cost. **cost** $C\ d$ adds a cost $C$ to measures due to $d$. This construct is not expressive in the traditional sense, as it does not affect layout results. However, it allows us to make *weighted* choices, so that we can prefer one style over another when all else is equal. Due to the flexibility of the cost factory, it is even possible to make multidimensional weights.

#### C.2 Safety

As shown in the proof of [Lemma 5.3](#), the traditional PPL is not functionally complete because all layouts must have the same content, modulo whitespaces. While this property is restrictive for many tasks as elaborated in the paper, it does provide a sort of safety guarantee that the layouts will not be wildly different. `<|>`, however, allows us to violate this property. In fact, some arbitrary-choice printers (e.g. a prototype of Bernardy’s printer [Bernardy 2015]) *intend* that `<|>` should be restricted to maintain the property. Similarly, the inclusion of **fail**, **newline**, or **full** makes it possible to evaluate to an empty set, but the PPLs without the essence of **fail** provide a safety guarantee that an evaluation will never result in an empty set. Generally, the more expressive a language is, the more properties it will break, and the more burden will be put on the users to carefully use the constructs.

We argue that the spirit of these safety properties can still be accomplished in PPLs with a functionally complete core. One possible approach is similar to Wadler’s treatment of `<|>` and **group**: define high-level, “safe” constructs with just enough expressiveness to solve a domain-specific task, based on the core, “unsafe” constructs, and then hide these “unsafe” constructs away from the external interface. For example, one may hide `<|>`, and instead provide `groupParen(d) = (text "(" <> d <> text ")") <|> flatten d`, which evaluates to either $d$ with parentheses wrapped around, or the flattened $d$. The language as defined by the external interface is no longer functionally complete, but enjoys the property that all layouts are the same modulo whitespaces and parentheses. Another possible approach is to export the core, “unsafe” constructs, but perform a static analysis to ensure that the document satisfies intended safety properties.

In any case, the expressive core constructs are what enable the advanced features that languages may require to be rendered well. Thus, our view is that an expressive printer is the key. We should start with an expressive albeit unsafe printer, rather than a safe but non-expressive one.

#### C.3 Memoization

While memoization is important to guarantee that $\Pi_e$ will not take exponential time, it is also the performance bottleneck when the input document is large, due to too much memory allocation. In PRETTYEXPRESSIVE, we employ a heuristic to reduce memory allocation by adding a metadata *memoization weight* to each document node, which counts how long memoization has not been performed on descendant nodes. When the weight reaches a limit (set to 6 in our implementation), we perform memoization on the node, and reset the weight to 0. This can significantly speed up the performance of PRETTYEXPRESSIVE on some large documents.

#### C.4 Fusing Resolving and Rendering

One optimization in PRETTYEXPRESSIVE is to fuse together the resolving of a document to a measure set and the rendering of a choiceless document to a layout. This is done by replacing the doc component in a measure with a *token function*, which consumes a list of rendered tokens *after* the document is placed, and returns a new list of rendered tokens. A similar technique was employed by Podkopaev and Boulytchev [2015].

#### C.5 Handling Bias in the Presence of Taintedness

In Section 6, we see that the merge operation and thus the `<|>` operator is left-biased in the presence of taintedness. When exceeding $\mathcal{W}$ is unavoidable, all text could be put in one line in the worst case if all left sub-documents use the “horizontal styling”! The proper solution is to increase $\mathcal{W}$. However, PRETTYEXPRESSIVE also implements a heuristic to infer a sub-document with the “vertical styling.” The heuristic adds a metadata that overestimates the number of lines for each document node. PRETTYEXPRESSIVE then uses a document with a larger overestimated number of lines as the left sub-document in choice documents.

#### C.6 Partial Evaluation

Similar to how we can perform partial evaluation in programming languages, we can also perform partial evaluation in PPL using rewriting rules. For example, a concatenation of two `text` can immediately be partially evaluated to a single `text`. However, this partial evaluation must be done with care to still preserve the sharing structure, since unconstrained rewriting may unfold the DAG structure into a tree, as illustrated in Figure 19. It is also worth noting that the partial evaluation may not necessarily preserve the semantics in the presence of taintedness. For example, one may want to reduce a `nest n (text s)` to `text s` for any $n$ and $s$, but when $n > \mathcal{W}$, the document will definitely resolve to a tainted measure set, while the partially evaluated one does not necessarily.[^21]

### REFERENCES

- Pablo R Azero Alcocer and S Doaitse Swierstra. 1998. Optimal pretty-printing combinators. [https://web.archive.org/web/20040911044443/http://www.cs.uu.nl/groups/ST/Software/PP/pabloicfp.ps](https://web.archive.org/web/20040911044443/http://www.cs.uu.nl/groups/ST/Software/PP/pabloicfp.ps).
- Jean-Philippe Bernardy. 2015. Towards The Prettiest Printer. [https://jyp.github.io/posts/towards-the-prettyest-printer.html](https://jyp.github.io/posts/towards-the-prettyest-printer.html).
- Jean-Philippe Bernardy. 2017a. Disjunctionless. [https://github.com/jyp/prettyest/pull/10](https://github.com/jyp/prettyest/pull/10).
- Jean-Philippe Bernardy. 2017b. prettyest. [https://github.com/jyp/prettyest/blob/5e7a12cf37bb01467485bbe1e9d8f272fa4f8cd5/Text/PrettyPrint/Compact/Core.hs](https://github.com/jyp/prettyest/blob/5e7a12cf37bb01467485bbe1e9d8f272fa4f8cd5/Text/PrettyPrint/Compact/Core.hs).
- Jean-Philippe Bernardy. 2017c. A Pretty but Not Greedy Printer (Functional Pearl). *Proc. ACM Program. Lang.* 1, ICFP, Article 6 (Aug. 2017), 21 pages. [https://doi.org/10.1145/3110250](https://doi.org/10.1145/3110250)
- Olaf Chitil. 2005. Pretty Printing with Lazy Dequeues. *ACM Trans. Program. Lang. Syst.* 27, 1 (jan 2005), 163–184. [https://doi.org/10.1145/1053468.1053473](https://doi.org/10.1145/1053468.1053473)
- Joëlle Coutaz. 1984. The box, a layout abstraction for user interface toolkits. (Dec. 1984). [https://doi.org/10.1184/R1/6610382.v1](https://doi.org/10.1184/R1/6610382.v1)
- Merijn De Jonge. 2002. Pretty-printing for software reengineering. In *International Conference on Software Maintenance, 2002. Proceedings*. IEEE, 550–559.
- Leonardo De Moura and Nikolaj Bjørner. 2008. Z3: An Efficient SMT Solver. In *Proceedings of the 14th International Conference on Tools and Algorithms for the Construction and Analysis of Systems (TACAS)*. Budapest, Hungary, 337–340.
- ESLint. 2014. Change no-comma-dangle to comma-dangle. [https://github.com/eslint/eslint/issues/1350](https://github.com/eslint/eslint/issues/1350).
- Matthias Felleisen. 1991. On the expressive power of programming languages. *Science of Computer Programming* 17, 1 (1991), 35–75. [https://doi.org/10.1016/0167-6423(91)90036-W](https://doi.org/10.1016/0167-6423(91)90036-W)

[^21]: One may argue, however, that this semantic change is acceptable, because the change is for the better.

- Matthias Felleisen, Robert Bruce Findler, Matthew Flatt, Shriram Krishnamurthi, Eli Barzilay, Jay McCarthy, and Sam Tobin-Hochstadt. 2018. A Programmable Programming Language. *Commun. ACM* 61, 3 (March 2018), 62–71. [https://doi.org/10.1145/3127323](https://doi.org/10.1145/3127323)
- John Hughes. 1995. The design of a pretty-printing library. In *Advanced Functional Programming*, Johan Jeuring and Erik Meijer (Eds.). Springer Berlin Heidelberg, Berlin, Heidelberg, 53–96.
- Oleg Kiselyov, Simon Peyton-Jones, and Amr Sabry. 2012. Lazy v. Yield: Incremental, Linear Pretty-Printing. In *Programming Languages and Systems*, Ranjit Jhala and Atsushi Igarashi (Eds.). Springer Berlin Heidelberg, Berlin, Heidelberg, 190–206.
- Daan Leijen. 2000. wl-pprint: The Wadler/Leijen Pretty Printer. [https://hackage.haskell.org/package/wl-pprint](https://hackage.haskell.org/package/wl-pprint).
- Leonardo de Moura and Sebastian Ullrich. 2021. The Lean 4 Theorem Prover and Programming Language. In *Automated Deduction – CADE 28*, André Platzer and Geoff Suttcliffe (Eds.). Springer International Publishing, Cham, 625–635.
- Dereck C. Oppen. 1980. Prettyprinting. *ACM Trans. Program. Lang. Syst.* 2, 4 (Oct. 1980), 465–483. [https://doi.org/10.1145/357114.357115](https://doi.org/10.1145/357114.357115)
- Susan Owicki and David Gries. 1976. Verifying Properties of Parallel Programs: An Axiomatic Approach. *Commun. ACM* 19, 5 (May 1976), 279–285. [https://doi.org/10.1145/360051.360224](https://doi.org/10.1145/360051.360224)
- Simon Peyton-Jones. 1997. A pretty printer library in Haskell. [https://web.archive.org/web/20080221052958/http://research.microsoft.com/Users/simonpj/downloads/pretty-printer/pretty.html](https://web.archive.org/web/20080221052958/http://research.microsoft.com/Users/simonpj/downloads/pretty-printer/pretty.html). The identified mistakes are noted at [https://github.com/haskell/pretty/blob/5b70d1be6e17a644dc3b5c80592cf7c5b339fd9/Text/PrettyPrint/HughesPJ.hs](https://github.com/haskell/pretty/blob/5b70d1be6e17a644dc3b5c80592cf7c5b339fd9/Text/PrettyPrint/HughesPJ.hs).
- Anton Podkopaev and Dmitri Boulytchev. 2015. Polynomial-Time Optimal Pretty-Printing Combinators with Choice. In *Perspectives of System Informatics*, Andrei Voronkov and Irina Virbitskaite (Eds.). Springer Berlin Heidelberg, Berlin, Heidelberg, 257–265.
- Sorawee Porncharoenwase, Luke Nelson, Xi Wang, and Emina Torlak. 2022. A Formal Foundation for Symbolic Evaluation with Merging. *Proc. ACM Program. Lang.* 6, POPL, Article 47 (Jan. 2022), 28 pages. [https://doi.org/10.1145/3498709](https://doi.org/10.1145/3498709)
- Sorawee Porncharoenwase, Justin Pombrio, and Emina Torlak. 2023. Artifact for A Pretty Expressive Printer. [https://doi.org/10.5281/zenodo.8332960](https://doi.org/10.5281/zenodo.8332960)
- Prettier. 2016. Technical Details. [https://prettier.io/docs/en/technical-details.html](https://prettier.io/docs/en/technical-details.html).
- S Doaitse Swierstra, Pablo R Azero Alcocer, and Joao Saraiva. 1999. Designing and Implementing Combinator Languages. In *Third Summer School on Advanced Functional Programming, volume 1608 of LNCS*. Springer-Verlag, 150–206.
- The Python Language Reference. 2010. Lexical analysis. [https://docs.python.org/2.7/reference/lexical_analysis.html](https://docs.python.org/2.7/reference/lexical_analysis.html).
- Emina Torlak and Rastislav Bodik. 2014. A Lightweight Symbolic Virtual Machine for Solver-Aided Host Languages. In *Proceedings of the 35th ACM SIGPLAN Conference on Programming Language Design and Implementation (PLDI)*. Edinburgh, United Kingdom, 530–541. [https://doi.org/10.1145/2666356.2594340](https://doi.org/10.1145/2666356.2594340)
- Philip Wadler. 2003. A prettier printer. *The Fun of Programming, Cornerstones of Computing* (2003), 223–243.
- Phillip Yelland. 2015. rfmt: A code formatter for R. [https://github.com/google/rfmt](https://github.com/google/rfmt).
- Phillip Yelland. 2016. A New Approach to Optimal Code Formatting. Technical note for open source project rfmt; [https://github.com/google/rfmt](https://github.com/google/rfmt).

Received 2023-04-14; accepted 2023-08-27
