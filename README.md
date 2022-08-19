
# AlgorithmicRecourseDynamics

`AlgorithmicRecourseDynamics.jl` is a Julia package for modelling Algorithmic Recourse Dynamics.

## Research Paper 📝

**Note** ⚠: You are browsing the `#original-paper` branch of `AlgorithmicRecourseDynamics.jl`. This branch is a static artifact corresponding to the state of the package at the time the paper was first published. It can be used to replicate the original findings of the paper. Only this branch is currently accessible as an anonymised git repository. The main repository is private and will will be open-sourced after the review process.

## At a Glance

The paper titles **Endogenous Macrodynamics in Algorithmic Recourse** is currently under review and not yet published. You can find a preprint along with other resources right here on this branch of the repository:

-   [Paper](paper/paper.pdf)
-   [Notebooks](dev/notebooks/)
-   [Supplementary Appendix](build/dev/notebooks/appendix.html) (download the HTML and view in browser)
-   [Artifacts]() (including data and experimental results; link currently exluded due to double-blind review)

In this work we investigate what happens if Algorithmic Recourse is actually implemented by a large number of individuals. The chart below illustrates what we mean by Endogenous Macrodynamics in Algorithmic Recourse: (a) we have a simple linear classifier trained for binary classification where samples from the negative class ($y=0$) are marked in blue and samples of the positive class ($y=1$) are marked in orange; (b) the implementation of AR for a random subset of individuals leads to a noticable domain shift; (c) as the classifier is retrained we observe a corresponding model shift; (d) as this process is repeated, the decision boundary moves away from the target class.

![](paper/www/poc.png)

## Paper Abstract

Existing work on Counterfactual Explanations (CE) and Algorithmic Recourse (AR) has largely been limited to the static setting and focused on single individuals: given some estimated model the goal is to find valid counterfactuals for individual instance that fulfill various desiderata. The ability of such counterfactuals to handle dynamics like data and model drift remains a largely unexplored research challenge at this point. There has also been surprisingly little work on the related question of how the actual implementation of recourse by one individual may affect other individuals. Through this work we aim to close that gap by systematizing and extending existing knowledge. We first show that many of the existing methodologies can be collectively described by a generalized framework. We then argue that the existing framework fails to account for a hidden external cost of recourse, that only reveals itself when studying the endogenous dynamics of recourse at the group level. Through simulation experiments involving various state-of-the-art counterfactual generators and several benchmark datasets, we generate large numbers of counterfactuals and study the resulting domain and model shifts. We find that the induced shifts are substantial enough to likely impede the applicability Algorithmic Recourse in situations that involve competition for scarce resources. Fortunately, we find various potential mitigation strategies that can be used in combination with existing approaches. Our simulation framework for studying recourse dynamics is fast and open-sourced.
