defmodule Mindset.Training.DataLoader do
  @moduledoc """
  Loads and validates training data from CSV or JSONL files.
  Supports Instruction and Q&A formats with auto-detection.
  """
  require Logger

  @supported_formats ["csv", "jsonl"]

  @doc """
  Load and validate data from a file path.
  Returns {:ok, stats} or {:error, reason}
  """
  def load(file_path, format_type \\ nil) do
    ext = Path.extname(file_path) |> String.downcase() |> String.trim_leading(".")
    
    if ext not in @supported_formats do
      {:error, "Unsupported file format: .#{ext}. Supported: #{Enum.join(@supported_formats, ", ")}"}
    else
      case File.exists?(file_path) do
        false -> {:error, "File not found: #{file_path}"}
        true -> parse_file(file_path, ext, format_type)
      end
    end
  end

  @doc """
  Cache a copy of the training data to priv/training_data/
  """
  def cache_data(source_path, format_type) do
    cache_dir = Path.join(["priv", "training_data", generate_cache_id()])
    File.mkdir_p!(cache_dir)
    
    dest_path = Path.join(cache_dir, Path.basename(source_path))
    File.cp!(source_path, dest_path)
    
    # Save metadata
    metadata = %{
      original_path: source_path,
      cached_path: dest_path,
      format_type: format_type,
      cached_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    metadata_path = Path.join(cache_dir, "metadata.json")
    File.write!(metadata_path, Jason.encode!(metadata, pretty: true))
    
    {:ok, cache_dir, dest_path}
  end

  @doc """
  Show preview of the data (first N rows)
  """
  def preview(file_path, format_type, n \\ 5) do
    case load(file_path, format_type) do
      {:ok, %{samples: samples}} ->
        samples
        |> Enum.take(n)
        |> Enum.with_index(1)
        |> Enum.each(fn {sample, idx} ->
          Owl.IO.puts([Owl.Data.tag("\nExample #{idx}:\n", :cyan)])
          Owl.IO.puts([Owl.Data.tag("Prompt: ", :bright), sample.prompt])
          Owl.IO.puts([Owl.Data.tag("Response: ", :bright), sample.response])
        end)
        :ok
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Count tokens in prompts and responses using a tokenizer
  """
  def analyze_tokens(file_path, format_type, tokenizer) do
    case load(file_path, format_type) do
      {:ok, %{samples: samples}} ->
        stats = 
          Enum.reduce(samples, %{prompt_tokens: [], response_tokens: [], total: 0}, fn sample, acc ->
            prompt_tokens = length(tokenizer.(sample.prompt))
            response_tokens = length(tokenizer.(sample.response))
            
            %{
              prompt_tokens: [prompt_tokens | acc.prompt_tokens],
              response_tokens: [response_tokens | acc.response_tokens],
              total: acc.total + 1
            }
          end)
        
        avg_prompt = Enum.sum(stats.prompt_tokens) / stats.total
        avg_response = Enum.sum(stats.response_tokens) / stats.total
        max_prompt = Enum.max(stats.prompt_tokens)
        max_response = Enum.max(stats.response_tokens)
        
        {:ok, %{
          total_samples: stats.total,
          avg_prompt_tokens: avg_prompt,
          avg_response_tokens: avg_response,
          max_prompt_tokens: max_prompt,
          max_response_tokens: max_response
        }}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp parse_file(file_path, "csv", format_type) do
    # Read CSV and detect format
    file_path
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Enum.to_list()
    |> case do
      [] -> 
        {:error, "Empty CSV file"}
      
      rows ->
        headers = List.first(rows)
        
        # Auto-detect format if not specified
        detected_format = format_type || detect_csv_format(headers)
        
        samples = 
          rows
          |> Enum.drop(1)  # Skip header
          |> Enum.map(fn row -> 
            parse_csv_row(row, headers, detected_format)
          end)
          |> Enum.reject(&is_nil/1)
        
        {:ok, %{
          format: detected_format,
          total_samples: length(samples),
          samples: samples,
          headers: headers
        }}
    end
  end

  defp parse_file(file_path, "jsonl", format_type) do
    samples =
      file_path
      |> File.stream!()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Jason.decode!/1)
      |> Enum.map(fn obj -> 
        parse_jsonl_row(obj, format_type)
      end)
      |> Enum.reject(&is_nil/1)
    
    detected_format = format_type || :instruction
    
    {:ok, %{
      format: detected_format,
      total_samples: length(samples),
      samples: samples,
      headers: nil
    }}
  end

  defp detect_csv_format(headers) do
    headers_lower = Enum.map(headers, &String.downcase/1)
    
    cond do
      "prompt" in headers_lower and "response" in headers_lower ->
        :instruction
      
      "question" in headers_lower and "answer" in headers_lower ->
        :qa
      
      "instruction" in headers_lower and "input" in headers_lower and "output" in headers_lower ->
        :instruction_input
      
      true ->
        :unknown
    end
  end

  defp parse_csv_row(row, headers, :instruction) do
    data = Enum.zip(headers, row) |> Map.new()
    
    prompt = Map.get(data, "prompt") || Map.get(data, "Prompt")
    response = Map.get(data, "response") || Map.get(data, "Response")
    
    if prompt && response do
      %{prompt: prompt, response: response}
    else
      nil
    end
  end

  defp parse_csv_row(row, headers, :qa) do
    data = Enum.zip(headers, row) |> Map.new()
    
    question = Map.get(data, "question") || Map.get(data, "Question")
    answer = Map.get(data, "answer") || Map.get(data, "Answer")
    
    if question && answer do
      %{
        prompt: "Question: #{question}\nAnswer:",
        response: answer
      }
    else
      nil
    end
  end

  defp parse_csv_row(row, headers, :instruction_input) do
    data = Enum.zip(headers, row) |> Map.new()
    
    instruction = Map.get(data, "instruction") || Map.get(data, "Instruction")
    input = Map.get(data, "input") || Map.get(data, "Input")
    output = Map.get(data, "output") || Map.get(data, "Output")
    
    if instruction && output do
      prompt = if input && input != "", do: "#{instruction}\n\n#{input}", else: instruction
      %{prompt: prompt, response: output}
    else
      nil
    end
  end

  defp parse_csv_row(_row, _headers, :unknown) do
    nil
  end

  defp parse_jsonl_row(%{"prompt" => prompt, "response" => response}, _format) do
    %{prompt: prompt, response: response}
  end

  defp parse_jsonl_row(%{"question" => question, "answer" => answer}, _format) do
    %{
      prompt: "Question: #{question}\nAnswer:",
      response: answer
    }
  end

  defp parse_jsonl_row(%{"instruction" => instruction, "output" => output} = obj, _format) do
    input = Map.get(obj, "input", "")
    prompt = if input != "", do: "#{instruction}\n\n#{input}", else: instruction
    %{prompt: prompt, response: output}
  end

  defp parse_jsonl_row(_obj, _format) do
    nil
  end

  defp generate_cache_id do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
    |> Integer.to_string()
  end
end