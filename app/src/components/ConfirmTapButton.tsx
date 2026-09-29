"use client";

import { useEffect, useRef, useState } from "react";

const ARM_TIMEOUT_MS = 3000;

export default function ConfirmTapButton({
  onConfirm,
  idleLabel,
  confirmLabel,
  className,
  disabled,
}: {
  onConfirm: () => void;
  idleLabel: string;
  confirmLabel: string;
  className?: string;
  disabled?: boolean;
}) {
  const [armed, setArmed] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(
    () => () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    },
    [],
  );

  function handleClick() {
    if (!armed) {
      setArmed(true);
      timeoutRef.current = setTimeout(() => setArmed(false), ARM_TIMEOUT_MS);
      return;
    }
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    setArmed(false);
    onConfirm();
  }

  return (
    <button type="button" onClick={handleClick} disabled={disabled} className={className}>
      {armed ? confirmLabel : idleLabel}
    </button>
  );
}
