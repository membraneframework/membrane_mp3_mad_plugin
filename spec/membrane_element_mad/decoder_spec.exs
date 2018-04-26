defmodule Membrane.Element.Mad.DecoderSpec do
  use ESpec, asyn: true
  alias Membrane.Element.Mad.Decoder.Native
  require Membrane.Caps.Audio.MPEG

  @minimal_mpeg_frame <<255, 243, 20, 196, 0, 0, 0, 3, 72, 0, 0, 0, 0, 76, 65, 77, 69, 51, 46, 57,
                        54, 46, 49, 85, 255, 243, 20, 196, 11, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85,
                        85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196, 22, 0, 0, 3, 72, 0,
                        0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196,
                        33, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85>>
  @minimal_frame_rate 24000
  @minimal_frame_channels 1

  describe ".handle_init/1" do
    let :options, do: nil

    it "should return ok result" do
      expect(described_module().handle_init(options())) |> to(be_ok_result())
    end

    it "should return queue as a bitstring" do
      {:ok, %{queue: queue}} = described_module().handle_init(options())
      expect(queue) |> to(be_bitstring())
    end

    it "should return empty queue" do
      {:ok, %{queue: queue}} = described_module().handle_init(options())
      expect(queue) |> to(be_empty())
    end
  end

  describe ".handle_prepare/1" do
    let :state, do: %{queue: <<>>, native: nil, source_caps: nil}

    it "should return ok result" do
      expect(described_module().handle_prepare(:stopped, state())) |> to(be_ok_result())
    end
  end

  describe ".handle_buffer/4" do
    let :channels, do: 2
    let :caps, do: %Membrane.Caps.Audio.MPEG{channels: channels()}
    let :context, do: %{}
    let :native, do: elem(Native.create(), 1)
    let :buffer, do: %Membrane.Buffer{payload: frame()}

    context "queue is empty" do
      let :state, do: %{native: native(), source_caps: nil, queue: <<>>}

      context "frame is contained in the buffer" do
        let :frame, do: @minimal_mpeg_frame

        it "shoud return ok tuple" do
          {{result_atom, _decoded}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(result_atom) |> to(eq(:ok))
        end

        it "should send non empty buffer" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {_pad, buffer} = keyword_list |> Keyword.get(:buffer)

          expect(buffer.payload) |> to(be_bitstring())
          expect(byte_size(buffer.payload) |> to(be :>, 0))
        end

        it "should send buffer on 'source' pad" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {pad, _buffer} = keyword_list |> Keyword.get(:buffer)
          expect(pad) |> to(eq :source)
        end

        it "should return state with new queue" do
          {{_result_atom, _nbuf}, %{queue: new_queue}} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(new_queue) |> to(be_bitstring())
        end

        it "should send new caps on 'source' pad" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {pad, _caps} = keyword_list |> Keyword.get(:caps)
          expect(pad) |> to(eq :source)
        end

        it "should return caps with proper channels number, format and sample_rate" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {_pad, caps} = keyword_list |> Keyword.get(:caps)

          expect(caps)
          |> to(
            eq %Membrane.Caps.Audio.Raw{
              format: :s24le,
              sample_rate: @minimal_frame_rate,
              channels: @minimal_frame_channels
            }
          )
        end
      end

      context "buffer is not big enough" do
        let :frame, do: <<1, 2, 3, 4>>

        it "should return an ok result" do
          {result, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(result) |> to(be_ok_result())
        end

        it "should append buffer to the queue" do
          {_result, new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(new_state.queue) |> to(eq frame())
        end
      end
    end

    context "queue is not empty" do
      let :queue do
        <<prefix::binary-size(10), _rest::binary>> = @minimal_mpeg_frame
        prefix
      end

      let :state, do: %{source_caps: nil, native: native(), queue: queue()}

      context "frame is contained in the queue and buffer" do
        let :frame do
          <<_::binary-size(10), suffix::binary>> = @minimal_mpeg_frame
          suffix
        end

        it "shoud return ok tuple" do
          {{result_atom, _decoded}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(result_atom) |> to(eq(:ok))
        end

        it "should send non empty buffer" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {_pad, buffer} = keyword_list |> Keyword.get(:buffer)

          expect(buffer.payload) |> to(be_bitstring())
          expect(byte_size(buffer.payload) |> to(be :>, 0))
        end

        it "should send buffer on 'source' pad" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {pad, _buffer} = keyword_list |> Keyword.get(:buffer)
          expect(pad) |> to(eq :source)
        end

        it "should return state with new queue" do
          {{_result_atom, _nbuf}, %{queue: new_queue}} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(new_queue) |> to(be_bitstring())
        end

        it "should send new caps on 'source' pad" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {pad, _caps} = keyword_list |> Keyword.get(:caps)
          expect(pad) |> to(eq :source)
        end

        it "should return caps with proper channels number, format and sample_rate" do
          {{_result_atom, keyword_list}, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          {_pad, caps} = keyword_list |> Keyword.get(:caps)

          expect(caps)
          |> to(
            eq %Membrane.Caps.Audio.Raw{
              format: :s24le,
              sample_rate: @minimal_frame_rate,
              channels: @minimal_frame_channels
            }
          )
        end
      end

      context "frame is not contained in the queue and buffer" do
        let :frame, do: <<0, 0>>

        it "should return an ok result" do
          {result, _new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(result) |> to(be_ok_result())
        end

        it "should append buffer to the queue" do
          {_result, new_state} =
            described_module().handle_process1(:sink, buffer(), context(), state())

          expect(new_state.queue) |> to(eq(queue() <> frame()))
        end
      end
    end
  end
end
