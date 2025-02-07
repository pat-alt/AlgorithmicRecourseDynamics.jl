using CounterfactualExplanations: counterfactual, counterfactual_label, generate_counterfactual
using CounterfactualExplanations.DataPreprocessing
using DataFrames
using Flux
using ..Models
using Parameters
using StatsBase

@with_kw mutable struct FixedParameters
    n_rounds::Int = 50
    n_folds::Int = 5
    seed::Union{Nothing,Int} = nothing
    T::Int = 100
    μ::AbstractFloat = 0.05
    intersect_::Bool = true
    convergence::Symbol = :threshold_only
    generative_model_params::NamedTuple = (;)
    latent_space::Union{Nothing,Bool} = nothing
end

mutable struct Experiment
    data::CounterfactualExplanations.CounterfactualData
    train_data::CounterfactualExplanations.CounterfactualData
    test_data::CounterfactualExplanations.CounterfactualData
    target::Number
    recourse_systems::Union{Nothing,AbstractArray}
    system_identifiers::Base.Iterators.ProductIterator
    fixed_parameters::Union{Nothing,FixedParameters}
    models::Union{NamedTuple,Dict}
    generators::Union{NamedTuple,Dict}
    num_counterfactuals::Int
    initial_model_scores::Vector
end


"""
    Experiment(data::CounterfactualExplanations.CounterfactualData, target::Number, models::NamedTuple, generators::NamedTuple)


"""
function Experiment(
    train_data::CounterfactualExplanations.CounterfactualData, test_data::CounterfactualExplanations.CounterfactualData, target::Number, models::Union{NamedTuple,Dict}, generators::Union{NamedTuple,Dict}, num_counterfactuals::Int=1
)

    # Add system identifiers:
    system_identifiers = Base.Iterators.product(keys(models), keys(generators))

    # Full data:
    data = hcat(train_data, test_data)

    # Initial scores:
    initial_model_scores = [(name, Models.model_evaluation(model, test_data)) for (name, model) in pairs(models)]

    experiment = Experiment(
        data, # initial data is owned by the experiment, shared across recourse systems,
        train_data,
        test_data,
        target,
        nothing,
        system_identifiers,
        nothing,
        models,
        generators,
        num_counterfactuals,
        initial_model_scores
    )

    return experiment
end

function set_up_system_grid!(experiment::Experiment, K::Int=1)

    data = experiment.train_data
    grid = Base.Iterators.product(values(experiment.models), values(experiment.generators))

    # Set up systems grid
    recourse_systems = map(1:K) do k
        map(grid) do vars
            newdata = deepcopy(data)
            model = deepcopy(vars[1]) # initial model is owned by the recourse systems
            score = Models.model_evaluation(model, experiment.test_data)
            newmodel = deepcopy(model)
            generator = vars[2]
            recourse_system = RecourseSystem(newdata, newmodel, generator, model, score, nothing, DataFrame())
            return recourse_system
        end
    end
    experiment.recourse_systems = recourse_systems
end

"""
    Experiment(X::AbstractArray,y::AbstractArray,M::CounterfactualExplanations.AbstractFittedModel,target::AbstractFloat,grid::Base.Iterators.ProductIterator,n_rounds::Int)

Sets up the experiment to be run.
"""
mutable struct RecourseSystem
    data::CounterfactualExplanations.CounterfactualData
    model::CounterfactualExplanations.AbstractFittedModel
    generator::CounterfactualExplanations.Generators.AbstractGenerator
    initial_model::CounterfactualExplanations.AbstractFittedModel
    initial_score::AbstractFloat
    chosen_individuals::Union{Nothing,AbstractArray}
    benchmark::DataFrame
end

"""
    choose_individuals(system::RecourseSystem, target::Number)
    
"""
function choose_individuals(experiment::Experiment, recourse_systems::AbstractArray; intersect_::Bool=true)
    args = experiment.fixed_parameters
    target, μ = experiment.target, args.μ

    candidates = map(recourse_systems) do sys
        ŷ = probs(sys.model, sys.data.X)
        n_classes = size(sys.data.y, 1)
        if n_classes == 1
            cand_ = findall(round.(vec(ŷ)) .!= target)
        else
            ŷ = Flux.onecold(ŷ, 1:n_classes)
            cand_ = findall(vec(ŷ) .!= target)
        end
        return cand_
    end

    if intersect_
        candidates_intersect = intersect(candidates...)
        n_individuals = Int(round(μ * length(candidates_intersect)))
        chosen_individuals = StatsBase.sample(candidates_intersect, n_individuals, replace=false)
        chosen_individuals = map(candidates) do x
            sort(chosen_individuals)
        end
    else
        chosen_individuals = map(candidates) do x
            n_individuals = Int(round(μ * length(x)))
            sort(StatsBase.sample(x, n_individuals, replace=false))
        end
    end

    return chosen_individuals
end


"""

"""
function update_experiment!(experiment::Experiment, recourse_system::RecourseSystem, chosen_individuals::AbstractVector)

    # Recourse System:
    counterfactual_data = recourse_system.data
    X, y = DataPreprocessing.unpack_data(counterfactual_data)
    M = recourse_system.model
    generator = recourse_system.generator

    # Experiment:
    args = experiment.fixed_parameters
    T = args.T
    target = experiment.target

    if length(chosen_individuals) > 0

        # Generate recourse:
        factuals = select_factual(counterfactual_data, chosen_individuals)

        results = generate_counterfactual(
            factuals, target, counterfactual_data, M, generator;
            T=T, num_counterfactuals=experiment.num_counterfactuals, generative_model_params=args.generative_model_params,
            latent_space=args.latent_space
        )

        # Unwrap new data:
        indices_ = rand(1:experiment.num_counterfactuals, length(results)) # randomly draw from generated counterfactuals
        X′ = reduce(hcat, @.(selectdim(counterfactual(results), 3, indices_)))
        y′ = reduce(hcat, @.(selectdim(counterfactual_label(results), 3, indices_)))

    # If for any counterfactuals the returned label is NaN, this is considered as invalid and the current label is not updated:
    valid_ces = vec(.!(isnan.(y′)))
    chosen_individuals = chosen_individuals[valid_ces]

    # Update data:
    X[:, chosen_individuals] = X′[:, valid_ces]
    y[:, chosen_individuals] = y′[:, valid_ces]

        # Generative model:
        gen_mod = deepcopy(counterfactual_data.generative_model)
        if !isnothing(gen_mod)
            CounterfactualExplanations.GenerativeModels.retrain!(gen_mod, X, y)
        end

        # Update data, classifier and benchmark:
        recourse_system.data.X = X
        recourse_system.data.y = y
        recourse_system.data.generative_model = gen_mod
        recourse_system.model = CounterfactualExplanations.Models.train(M, counterfactual_data)
        recourse_system.benchmark = vcat(recourse_system.benchmark, CounterfactualExplanations.Benchmark.benchmark(results))

    end

end





