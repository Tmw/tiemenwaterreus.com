---
title: "Linear Regression with Elixir, Phoenix and Liveview. Part I"
date: 2020-04-28T22:30:03+02:00
draft: true
keywords: linrear regression, machine learning, elixir, liveview
description: Writing a basic linear regression algorithm in Elixir and make it interactive using Phoenix Live View
icon: 📈
---

Phoenix Liveview has been around for [a bit](https://www.youtube.com/watch?v=8xJzHq8ru0M), but with the release of Phoenix 1.5, it became even easier to get started with it in a new Phoenix app! Simply pass the `--live` flag when generating a new project and off you go! 🚀

In this two part series we're getting our hands dirty with a basic linear regression model where we allow the user to click on a plane to add data points and let our model predict the best fitting line to these points.

[INSERT VISUAL HERE]

## Let’s get started

To kick things off, we first need to get up-to-date with our Phoenix version, if you have not already done this. You can do so by running: `mix archive.install hex phx_new`

Note that; if you rather get LiveView to work on Phoenix 1.4.x, just follow [the getting started guide](https://hexdocs.pm/phoenix_live_view/installation.html).

## Setting up the project

Scaffolding the starting off point of this project is as easy as as running: `mix phx.new linreg --live --no-ecto`. Note the two flags there:

- `--no-ecto` will skip setting up all the Ecto related things such as migrations and a Repo. Since we won’t be using those in this project, we can go ahead and skip the generation of these.

- `--live` will ensure everything related to LiveView will be installed, wired up and ready to go!

Next: `cd` into the folder and run the development server by running `mix phx.server`. Point your browser to http://localhost:4000 and you should be greeted with a welcome page 🎉

## Basic model

Now that we have a new Elixir project loaded with Phoenix and LiveView, time to get to the real stuff! First things first, let’s define a model for our application to work off of. A simple struct that holds the weights will do!

Fire up your favorite editor and drop in a new file under `lib/linreg/`. Let’s call it `model.ex` by lack of a better term and write the following code:

```elixir
defmodule Linreg.Model do
  defstruct m: 0.0, b: 0.0

  alias __MODULE__

  def new do
    %Model{}
  end

  def predict(%Model{m: m, b: b}, x) do
    b + m * x
  end
end
```

The module, for now, is pretty basic. All it does is define a struct to keep track of two values, namely M and B, define a convenience function to initialize a new empty model and a function to make predictions based on the model.

## Making predictions

For our prediction function, we’re using a slope-intercept form and we’re letting the machine learn the correct values for M and B, so that our function will output the correct Y. In machine learning the M and B are referred to as weights, and sometimes written as W1 and W2.

Now, let’s fire up an IEx shell (`iex -S mix`) and make some predictions!

```elixir
iex> m = Linreg.Model.new
%Linreg.Model{b: 0.0, m: 0.0}

iex> Linreg.Model.predict(m, 2)
0.0

iex> Linreg.Model.predict(m, 6)
0.0

iex> Linreg.Model.predict(m, 8)
0.0
```

In the example above we’ve initialized a new model and asked it to make some predictions based on arbitrary X values, however it will always predict the same value: 0.0.

This is because our model hasn't been trained yet. Or, in other words, our _machine_ hasn't _learned_ the correct values for M and B yet. It will always use the default values `0.0` which will always result in the same prediction.

## How does training work?

There’s a variety of ways to let the machine learn the correct values for M and B. Basically it all boils down to: 1) let the machine make a prediction, 2) calculate how far it’s off (often called error, loss or cost), 3) adjust the weights accordingly and repeat. Repeat until the error is acceptably low.

## Gather training data

In order to correctly train our model, we need training data. Training data in our case means a set of X and Y values. The model can learn from these values by making a prediction and see how far its prediction is off of the actual Y value.

In the `lib/linreg` folder, go ahead and make a new file called `data.ex` and write the following code:

```elixir
defmodule Linreg.Data do
  defstruct points: []
  alias __MODULE__

  def new do
    %Data{}
  end

  def add_point(%Data{points: points} = data, x, y) do
    %Data{data | points: [{x, y}] ++ points}
  end
end
```

In this module we define a struct that will describe our training data. In this case a single field called `points` that is a list. It will contain X and Y tuples. We define a function to initialize our `%Data{}`-struct and another function `add_point/3` that will add the passed point to our dataset.

## Adjusting the weights

Now that we have a data structure to keep track of correct X and Y values, we can start implementing the training function of our model. Head back to `lib/linreg/model.ex` and write the following function:

```elixir
def train(%Model{m: m, b: b} = model, %Data{points: points}, opts \\ []) do
  learning_rate = Keyword.get(opts, :learning_rate, 0.01)

  m_error =
    points
    |> Enum.map(fn {x, y} -> x * (predict(model, x) - y) end)
    |> Enum.sum()
    |> Kernel./(length(points))

  b_error =
    points
    |> Enum.map(fn {x, y} -> predict(model, x) - y end)
    |> Enum.sum()
    |> Kernel./(length(points))

  %Model{model | m: m - m_error * learning_rate, b: b - b_error * learning_rate}
end
```

The `train/3` function takes the current model, training data and a list of options. Then for each point in the training set, it will make a prediction of the Y value given its X value and calculate how far it is off.

It will do this for both the M and the B values. Only difference is that for M we’re constraining the outcome by multiplying it with its input X value. Once we have the errors for each datapoint, we sum those together and devide it by the amount of datapoints to get the average.

Once we have the average error of the model, it's time to adjust the weights based on the calculated average error. We multiply the average error by a _learning rate_ and subtract the result from the current M and B values.

> **Note** The learning rate is a value, often between 0 and 1, which determines _how quick_ the machine learns. It ensures that the adjustments to the weights are done in very small steps as to not overshoot the optimum value. This process is called gradient descent and is a very common technique within machine learning algorithms.

## Taking it for a spin

That’s pretty much all there is to it! Now let’s take it for a spin and see how it works. Fire up an iEX shell again and let’s make some predictions.

```elixir
# Initialize new trainings data and a new model
iex> d = Linreg.Data.new
%Linreg.Data{points: []}

iex> m = Linreg.Model.new
%Linreg.Model{b: 0.0, m: 0.0}

# Add some known data to the training set
iex> d = Linreg.Data.add_point(d, 2, 4)
%Linreg.Data{points: [{2, 4}]}

iex> d = Linreg.Data.add_point(d, 6, 12)
%Linreg.Data{points: [{6, 12}, {2, 4}]}

# Train the model
iex> m = Model.train(m, d)
%Linreg.Model{b: 0.08, m: 0.4}

# Predict our first value
iex> Model.predict(m, 5)
2.08
```

In the example above we’ve created a model and fed it some pretty straight forward trainings data where `Y = 2 * x`. We trained our model and let it make a prediction for 5. We expect it to predict 10, however it predicts 2 and some change.. We are getting closer, but still pretty far off.

What we see here is the learning rate in effect! We take smaller steps so we don’t overshoot our goal, however that also means that simply iterating over the training set once, will not cut it.

> In machine learning; iterating over the trainings set once is referred to as one epoch. In most machine learning algorithms, it requires iterating over your data set many times. Each time shaving a couple points off of that error rate, each time perfecting the model’s weights a bit more.

You’ll notice that, if you run the training and prediction again, the values shift a little more towards what you’d expect. However keeping on calling the train function manually is no fun. Let’s fix that!

## Multiple epochs

In order to make training for multiple epochs a little easier, let’s revisit the `train/3` function one more time and make it iterate over the entire training set multiple times.

```elixir
def train(%Model{} = model, %Data{points: points}, opts \\ []) do
  learning_rate = Keyword.get(opts, :learning_rate, 0.01)
  epochs = Keyword.get(opts, :epochs, 100)

  for _epoch <- 1..epochs, reduce: model do
    %Model{m: m, b: b} = model ->
      m_error =
        points
        |> Enum.map(fn {x, y} -> x * (predict(model, x) - y) end)
        |> Enum.sum()
        |> Kernel./(length(points))

      b_error =
        points
        |> Enum.map(fn {x, y} -> predict(model, x) - y end)
        |> Enum.sum()
        |> Kernel./(length(points))

      %Model{model | m: m - m_error * learning_rate, b: b - b_error * learning_rate}
  end
end
```

We've made a few changes to the train function. First off: We’re defining an epoch value which will influence how many times we run through the entire training set. Secondly; we wrapped the whole function body in an for comprehension so that we can iterate through the entire training set multiple times, each time adjusting the weights a little bit more.

> Note that we’re using a [comprehension with the reduce option](https://hexdocs.pm/elixir/Kernel.SpecialForms.html?#for/1-the-reduce-option). This is essentially the same as [`Enum.reduce/3`](https://hexdocs.pm/elixir/Enum.html#reduce/3) but is a little easier on the eyes with larger bodies, but that might just be a matter of taste 😗.

## More training

Now that we’ve advanced our training function, let’s try it out and see if our predictions will get a little closer this time! Fire up the iEX again (`iex -S mix`) and run:

```elixir
iex> d = Linreg.Data.add_point(d, 2, 4)
%Linreg.Data{points: [{2, 4}]}

iex> d = Linreg.Data.add_point(d, 8, 16)
%Linreg.Data{points: [{8, 16}, {2, 4}]}

iex> m = Linreg.Model.train(m, d)
%Linreg.Model{b: 0.22374565348607184, m: 1.966843594782793}

iex> Linreg.Model.predict(m, 5)
10.057963627400037
```

Hooray! We trained our model the formula `Y = 2 * X + 0`. More or less. As you can see the values for M and B are still a bit off, but given enough training, these values will approach the correct values more and more. Note, I’m saying approach here; they will never exactly be 2 and 0. This is mainly due to the learning rate, but floating point arithmetic is also to blame here.

Note that in the example above it is using a learning rate of 0.01 and trains for 100 epochs, these values are overridable in the options and will yield different results. Simply by calling our training function with the options list:

```elixir
iex> m = Model.train(m, d, learning_rate: 0.1, epochs: 500)
```

I’ll leave it as an exercise to the reader to play a bit with these values and see what happens. It may occasionally raise an ArithmeticError as the float values become too small.

That’s it for this post! We built a machine learning model that can be used for linear regressions and trained it using gradient descent in Elixir. In the next part we’ll look at how we can make this an interactive example using Phoenix Liveview where the user can input some data and let the machine figure out the linear regression.
