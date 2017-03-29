defmodule Membrane.Element.Mad.DecoderSpec do
  use ESpec, asyn: true
  alias Membrane.Element.Mad.DecoderNative
  require Membrane.Caps.Audio.MPEG

  let :options, do: %{}

  describe ".handle_prepare/1" do
    it "should return ok result" do
      expect(described_module.handle_prepare(options)).to be_ok_result
    end

    it "should return queue as a bitstring" do
      {:ok, %{queue: queue}} = described_module.handle_prepare(options)
      expect(queue).to be_bitstring
    end

    it "should return empty queue" do
      {:ok, %{queue: queue}} = described_module.handle_prepare(options)
      expect(queue).to be_empty
    end
  end

  describe ".handle_buffer/4" do
    let :channels, do: 2
    let :caps, do: %Membrane.Caps.Audio.MPEG{channels: channels}
    let :native, do: elem(Membrane.Element.Mad.DecoderNative.create, 1)
    let :buffer, do: %Membrane.Buffer{payload: frame}

    context "queue is empty" do
      let :state, do: %{native: native, queue: <<>>}

      context "frame is contained in the buffer" do
      let :frame, do: <<255, 243, 20, 196, 0, 0, 0, 3, 72, 0, 0, 0, 0, 76, 65, 77, 69, 51, 46, 57, 54, 46, 49, 85, 255, 243, 20, 196, 11, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196, 22, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196, 33, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85 >>

        it "shoud return ok tuple" do
          {result_atom, _decoded, _new_state} = described_module.handle_buffer(:sink, caps, buffer, state)
          expect(result_atom).to eq(:ok)
        end

        it "should return non empty result" do
          {_result_atom, [{:send, {:source, %Membrane.Buffer{payload: decoded}}}], _new_state} = described_module.handle_buffer(:sink, caps, buffer, state)
          expect(decoded).to be_bitstring
          expect byte_size(decoded) |> to(be :>, 0)
        end

        it "should return state with new queue" do
          {_result_atom, _nbuf, %{queue: new_queue}} = described_module.handle_buffer(:sink, caps, buffer, state)
          expect(new_queue).to be_bitstring
        end

        pending "should return caps with proper channels number"
        pending "should return caps with proper sample_rate"
      end

      context "buffer is not big enough" do
        pending "should return an ok result"
        pending "should append buffer to the queue"
      end

    end


    context "queue is not empty" do
      let :queue, do: <<255, 243, 20, 196, 0, 0, 0, 3, 72, 0>>
      let :state, do: %{native: native, queue: queue}

      context "frame is contained in the queue and buffer" do
        let :frame, do: <<0, 0, 0, 76, 65, 77, 69, 51, 46, 57, 54, 46, 49, 85, 255, 243, 20, 196, 11, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196, 22, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196, 33, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85 >>

        it "shoud return ok tuple" do
          {result_atom, _decoded, _new_state} = described_module.handle_buffer(:sink, caps, buffer, state)
          expect(result_atom).to eq(:ok)
        end

        it "should return non empty result" do
          {_result_atom, [{:send, {:source, %Membrane.Buffer{payload: decoded}}}], _new_state} = described_module.handle_buffer(:sink, caps, buffer, state)
          expect(decoded).to be_bitstring
          expect byte_size(decoded) |> to(be :>, 0)
        end

        it "should return state with new queue" do
          {_result_atom, _nbuf, %{queue: new_queue}} = described_module.handle_buffer(:sink, caps, buffer, state)
          expect(new_queue).to be_bitstring
        end

        pending "should return caps with proper channels number"
        pending "should return caps with proper sample_rate"

      end

      context "frame is not contained in the queue and buffer" do
        let :buffer, do: <<0,0>>

        pending "should return an ok result"
        #  expect(described_module.handle_buffer(:sink, caps, buffer, state)).to be_ok_result
        #end

        pending "should return new queue containing old queue concatenated with buffer"
        #   {_result_atom, %{queue: new_queue}} = described_module.handle_buffer(:sink, caps, buffer, state)
        #   expect(new_queue). to eq queue<>buffer
        #end

      end


    end

  end

end
