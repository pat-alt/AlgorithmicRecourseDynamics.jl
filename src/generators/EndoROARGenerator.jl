using LinearAlgebra, CounterfactualExplanations

mutable struct EndoROARGenerator <: AbstractGradientBasedGenerator
    loss::Union{Nothing,Symbol} # loss function
    complexity::Function # complexity function
    λ::Union{AbstractFloat,AbstractVector} # strength of penalty
    opt::Any # optimizer
    τ::AbstractFloat # tolerance for convergence
end

# API streamlining:
using Parameters, Flux
@with_kw struct EndoROARGeneratorParams
    opt::Any=Flux.Optimise.Descent()
    τ::AbstractFloat=1e-5
end

"""
    EndoROARGenerator(
        ;
        loss::Symbol=:logitbinarycrossentropy,
        complexity::Function=norm,
        λ::AbstractFloat=0.1,
        opt::Any=Flux.Optimise.Descent(),
        τ::AbstractFloat=1e-5
    )

An outer constructor method that instantiates a generic generator.

# Examples
```julia-repl
generator = EndoROARGenerator()
```
"""
function EndoROARGenerator(;loss::Union{Nothing,Symbol}=nothing,complexity::Function=norm,λ::Union{AbstractFloat,AbstractVector}=[0.1,5.0],kwargs...)
    params = EndoROARGeneratorParams(;kwargs...)
    EndoROARGenerator(loss, complexity, λ, params.opt, params.τ)
end

using Flux
function gradient_penalty(generator::EndoROARGenerator, counterfactual_state::CounterfactualState.State)
    
    x_ = counterfactual_state.f(counterfactual_state.s′)
    M = counterfactual_state.M
    nn = M.model
    y_ = counterfactual_state.y′

    loss_type = M.likelihood == :classification_binary ? :logitbinarycrossentropy : :logitcrossentropy
    loss(x, y) = getfield(Flux.Losses,loss_type)(nn(x), y)

    return loss(x_,y_)
end

# Complexity:
using Statistics, LinearAlgebra
using CounterfactualExplanations.CounterfactualState
import CounterfactualExplanations.Generators: h
"""
    h(generator::AbstractGenerator, counterfactual_state::CounterfactualState.State)

The default method to apply the generator complexity penalty to the current counterfactual state for any generator.
"""
function h(generator::EndoROARGenerator, counterfactual_state::CounterfactualState.State)
    
    # Distance from factual:
    dist_ = generator.complexity(counterfactual_state.x .- counterfactual_state.f(counterfactual_state.s′))

    # Euclidean norm of gradient:
    if all(counterfactual_state.y′.==counterfactual_state.target)
        grad_norm = gradient_penalty(generator, counterfactual_state)
    else
        grad_norm = 0
    end
    
    if length(generator.λ)==1
        penalty = generator.λ * (dist_ .+ grad_norm)
    else
        penalty = generator.λ[1] * dist_ .+ generator.λ[2] * grad_norm
    end
    return penalty
end


