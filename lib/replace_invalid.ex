defmodule Uni do
  @moduledoc """
  Copypasta'd out of Elixir 1.16.0-rc1 b/c I need this function to sanitize Valve's master list.
  """

  defguardp replace_invalid_ii_of_iii(i, ii)
            when Bitwise.bor(Bitwise.bsl(i, 6), ii) in 32..863 or
                   Bitwise.bor(Bitwise.bsl(i, 6), ii) in 896..1023

  defguardp replace_invalid_ii_of_iv(i, ii)
            when Bitwise.bor(Bitwise.bsl(i, 6), ii) in 16..271

  defguardp replace_invalid_iii_of_iv(i, ii, iii)
            when Bitwise.bor(Bitwise.bor(Bitwise.bsl(i, 12), Bitwise.bsl(ii, 6)), iii) in 1024..17407

  defguardp replace_invalid_is_next(next) when Bitwise.bsr(next, 6) !== 0b10

  @doc ~S"""
  Returns a new string created by replacing all invalid bytes with `replacement` (`"�"` by default).

  ## Examples

  iex> String.replace_invalid("asd" <> <<0xFF::8>>)
  "asd�"

  iex> String.replace_invalid("nem rán bề bề")
  "nem rán bề bề"

  iex> String.replace_invalid("nem rán b" <> <<225, 187>> <> " bề")
  "nem rán b� bề"

  iex> String.replace_invalid("nem rán b" <> <<225, 187>> <> " bề", "ERROR!")
  "nem rán bERROR! bề"
  """
  @doc since: "1.16.0"
  def replace_invalid(bytes, replacement \\ "�")
      when is_binary(bytes) and is_binary(replacement) do
    do_replace_invalid(bytes, replacement, <<>>)
  end

  # Valid ASCII (for better average speed)
  defp do_replace_invalid(<<ascii::8, next::8, _::bytes>> = rest, rep, acc)
       when ascii in 0..127 and replace_invalid_is_next(next) do
    <<_::8, rest::bytes>> = rest
    do_replace_invalid(rest, rep, acc <> <<ascii::8>>)
  end

  # Valid UTF-8
  defp do_replace_invalid(<<grapheme::utf8, rest::bytes>>, rep, acc) do
    do_replace_invalid(rest, rep, acc <> <<grapheme::utf8>>)
  end

  # 2/3 truncated sequence
  defp do_replace_invalid(<<0b1110::4, i::4, 0b10::2, ii::6>>, rep, acc)
       when replace_invalid_ii_of_iii(i, ii) do
    acc <> rep
  end

  defp do_replace_invalid(<<0b1110::4, i::4, 0b10::2, ii::6, next::8, _::bytes>> = rest, rep, acc)
       when replace_invalid_ii_of_iii(i, ii) and replace_invalid_is_next(next) do
    <<_::16, rest::bytes>> = rest
    do_replace_invalid(rest, rep, acc <> rep)
  end

  # 2/4
  defp do_replace_invalid(<<0b11110::5, i::3, 0b10::2, ii::6>>, rep, acc)
       when replace_invalid_ii_of_iv(i, ii) do
    acc <> rep
  end

  defp do_replace_invalid(
         <<0b11110::5, i::3, 0b10::2, ii::6, next::8, _::bytes>> = rest,
         rep,
         acc
       )
       when replace_invalid_ii_of_iv(i, ii) and replace_invalid_is_next(next) do
    <<_::16, rest::bytes>> = rest
    do_replace_invalid(rest, rep, acc <> rep)
  end

  # 3/4
  defp do_replace_invalid(<<0b11110::5, i::3, 0b10::2, ii::6, 0b10::2, iii::6>>, rep, acc)
       when replace_invalid_iii_of_iv(i, ii, iii) do
    acc <> rep
  end

  defp do_replace_invalid(
         <<0b11110::5, i::3, 0b10::2, ii::6, 0b10::2, iii::6, next::8, _::bytes>> = rest,
         rep,
         acc
       )
       when replace_invalid_iii_of_iv(i, ii, iii) and replace_invalid_is_next(next) do
    <<_::24, rest::bytes>> = rest
    do_replace_invalid(rest, rep, acc <> rep)
  end

  # Everything else
  defp do_replace_invalid(<<_, rest::bytes>>, rep, acc),
    do: do_replace_invalid(rest, rep, acc <> rep)

  # Final
  defp do_replace_invalid(<<>>, _, acc), do: acc
end
