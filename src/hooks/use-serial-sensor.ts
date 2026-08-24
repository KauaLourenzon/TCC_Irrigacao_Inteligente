import { useCallback, useEffect, useRef, useState } from "react";

import { insertReading } from "@/lib/plant-data";
import { evaluatePlantNow } from "@/lib/plant-proactive-actions";
export type SerialStatus = "disconnected" | "connecting" | "connected" | "unsupported" | "error";

type SerialReadingPayload = {
  soil_moisture: number;
  temperature?: number;
};

/**
 * Conecta um ESP32 via cabo USB usando a Web Serial API (Chrome/Edge) e
 * escuta linhas JSON tipo `{"soil_moisture":42,"temperature":24.1}\n`
 * enviadas pelo firmware, gravando cada uma como leitura da planta
 * `plantId`. Também permite mandar comandos de volta pro ESP32 (ex.:
 * "WATER\n" para acionar a bomba manualmente).
 *
 * Como a conexão é local (cabo), não precisamos de nenhum token de
 * pareamento: o próprio usuário escolhe, na hora, qual porta corresponde
 * a qual planta.
 */
export function useSerialSensor(plantId: string) {
  const [status, setStatus] = useState<SerialStatus>("disconnected");
  const [lastError, setLastError] = useState<string | null>(null);
  const [portLabel, setPortLabel] = useState<string | null>(null);

  const portRef = useRef<SerialPort | null>(null);
  const readerRef = useRef<ReadableStreamDefaultReader<Uint8Array> | null>(null);
  const writerRef = useRef<WritableStreamDefaultWriter<Uint8Array> | null>(null);
  const keepReadingRef = useRef(false);

  useEffect(() => {
    if (typeof navigator === "undefined" || !navigator.serial) {
      setStatus("unsupported");
    }
  }, []);

  const disconnect = useCallback(async () => {
    keepReadingRef.current = false;
    try {
      await readerRef.current?.cancel();
    } catch {
      // porta já pode ter sido fechada
    }
    readerRef.current = null;
    try {
      writerRef.current?.releaseLock();
    } catch {
      // ignora
    }
    writerRef.current = null;
    try {
      await portRef.current?.close();
    } catch {
      // ignora
    }
    portRef.current = null;
    setPortLabel(null);
    setStatus("disconnected");
  }, []);

  const handleLine = useCallback(
    (line: string) => {
      let payload: SerialReadingPayload;
      try {
        payload = JSON.parse(line) as SerialReadingPayload;
      } catch {
        return;
      }
      if (typeof payload.soil_moisture !== "number") return;

      insertReading(plantId, {
        soil_moisture: payload.soil_moisture,
        temperature: typeof payload.temperature === "number" ? payload.temperature : null,
      })
        .then(() => {
          evaluatePlantNow({ data: { plantId } }).catch((err) =>
            console.error("[assistente proativo] falha ao avaliar:", err),
          );
        })
        .catch((err) => {
          setLastError(err instanceof Error ? err.message : "Falha ao salvar leitura");
        });
    },
    [plantId],
  );

  const readLoop = useCallback(
    async (port: SerialPort) => {
      if (!port.readable) return;
      const reader = port.readable.getReader();
      readerRef.current = reader;
      const decoder = new TextDecoder();
      let buffer = "";
      try {
        while (keepReadingRef.current) {
          const { value, done } = await reader.read();
          if (done) break;
          if (value) {
            buffer += decoder.decode(value, { stream: true });
            let newlineIndex = buffer.indexOf("\n");
            while (newlineIndex >= 0) {
              const line = buffer.slice(0, newlineIndex).trim();
              buffer = buffer.slice(newlineIndex + 1);
              if (line) handleLine(line);
              newlineIndex = buffer.indexOf("\n");
            }
          }
        }
      } catch (err) {
        if (keepReadingRef.current) {
          setLastError(err instanceof Error ? err.message : "Conexão com o sensor perdida");
          setStatus("error");
        }
      } finally {
        try {
          reader.releaseLock();
        } catch {
          // ignora
        }
      }
    },
    [handleLine],
  );

  const connect = useCallback(async () => {
    if (typeof navigator === "undefined" || !navigator.serial) {
      setStatus("unsupported");
      return;
    }
    setStatus("connecting");
    setLastError(null);
    try {
      const port = await navigator.serial.requestPort();
      await port.open({ baudRate: 115200 });
      portRef.current = port;
      setPortLabel(
        (() => {
          const info = port.getInfo();
          return info.usbVendorId
            ? `USB ${info.usbVendorId.toString(16)}:${(info.usbProductId ?? 0).toString(16)}`
            : "Sensor conectado";
        })(),
      );
      if (port.writable) {
        writerRef.current = port.writable.getWriter();
      }
      keepReadingRef.current = true;
      setStatus("connected");
      void readLoop(port);
    } catch (err) {
      // usuário cancelou o seletor de porta, ou porta em uso
      setLastError(err instanceof Error ? err.message : "Não foi possível conectar ao sensor");
      setStatus(status === "connecting" ? "error" : status);
      setStatus("error");
    }
  }, [readLoop, status]);

  const sendCommand = useCallback(async (command: string) => {
    if (!writerRef.current) {
      throw new Error("Nenhum sensor conectado por USB.");
    }
    const encoder = new TextEncoder();
    await writerRef.current.write(encoder.encode(`${command}\n`));
  }, []);

  useEffect(() => () => void disconnect(), [disconnect]);

  return {
    status,
    lastError,
    portLabel,
    isSupported: status !== "unsupported",
    connect,
    disconnect,
    sendCommand,
  };
}
